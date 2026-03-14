(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})
(local target-frame-ms 17)

(fn now-ms
  []
  (math.floor (/ (vim.uv.hrtime) 1000000)))

(fn ensure-state
  [session]
  (let [state (or session.anim-state {})]
    (set session.anim-state state)
    state))

(fn next-token!
  [session key]
  (let [state (ensure-state session)
        token (+ 1 (or (. state key) 0))]
    (set (. state key) token)
    token))

(fn active-token?
  [session key token]
  (= (. (or session.anim-state {}) key) token))

(fn ease-out-cubic
  [t]
  (let [x (- 1 (math.max 0 (math.min t 1)))]
    (- 1 (* x x x))))

(fn lerp
  [a b t]
  (+ a (* (- b a) t)))

(fn number-or
  [v fallback]
  (if (= (type v) "number") v fallback))

(fn with-split-mins
  [f]
  (let [old-height vim.o.winminheight
        old-width vim.o.winminwidth
        old-equalalways vim.o.equalalways]
    (set vim.o.winminheight 1)
    (set vim.o.winminwidth 1)
    (set vim.o.equalalways false)
    (let [[ok res] [(pcall f)]]
      (set vim.o.winminheight old-height)
      (set vim.o.winminwidth old-width)
      (set vim.o.equalalways old-equalalways)
      (if ok
          res
          (error res)))))

(fn enabled?
  [session kind]
  (let [settings (or session.animation-settings {})
        entry (or (. settings kind) {})]
    (and (not (= false (. settings :enabled)))
         (not (= false (. entry :enabled))))))

(fn duration-ms
  [session kind fallback]
  (let [settings (or session.animation-settings {})
        entry (or (. settings kind) {})
        base (number-or (. entry :ms) fallback)
        global-scale (number-or (. settings :time-scale) 1.0)
        local-scale (number-or (. entry :time-scale) 1.0)]
    (math.max 0 (math.floor (+ 0.5 (* base global-scale local-scale))))))

(fn run!
  [session key opts]
  (let [{: duration-ms : steps : tick! : done! : active?} opts
        token (next-token! session key)
        total (math.max 1 (or steps 1))
        delay (math.max 8 target-frame-ms)
        last-frame-ms0 nil]
    (var last-frame-ms last-frame-ms0)
    (fn frame!
      [idx]
      (when (and (active-token? session key token)
                 (or (not active?) (active?)))
        (let [now (now-ms)
              elapsed (if last-frame-ms (- now last-frame-ms) delay)]
          (if (< elapsed delay)
              (vim.defer_fn (fn [] (frame! idx)) (- delay elapsed))
              (do
                (set last-frame-ms now)
                (let [t (ease-out-cubic (/ idx total))]
                  (tick! t idx total)
                  (if (< idx total)
                      (vim.defer_fn (fn [] (frame! (+ idx 1))) delay)
                      (when done!
                        (done!)))))))))
    (frame! 0)))

(fn animate-win-height!
  [session key win from to duration-ms opts]
  (let [start (math.max 1 from)
        stop (math.max 1 to)
        step (if (< start stop) 1 -1)
        opts (or opts {})]
    (with-split-mins
      (fn []
        (run! session key
              {:duration-ms duration-ms
               :steps (math.max 1 (math.abs (- stop start)))
               :active? (fn [] (vim.api.nvim_win_is_valid win))
               :tick! (fn [_ idx]
                        (let [height (math.max 1 (if (= idx 0)
                                                     start
                                                     (+ start (* idx step))))]
                          (pcall vim.api.nvim_win_set_height win height)
                          (when-let [tick! (. opts :tick!)]
                            (tick! height idx))))
               :done! (fn []
                        (pcall vim.api.nvim_win_set_height win stop)
                        (when-let [done! (. opts :done!)]
                          (done! stop)))})))))

(fn animate-win-height-stepwise!
  [session key win from to duration-ms opts]
  (let [start (math.max 1 from)
        stop (math.max 1 to)
        delta (math.abs (- stop start))
        direction (if (< start stop) 1 -1)
        frame-budget (math.max 1 (math.floor (/ (math.max duration-ms target-frame-ms) target-frame-ms)))
        stride (math.max 1 (math.ceil (/ (math.max 1 delta) frame-budget)))
        opts (or opts {})]
    (with-split-mins
      (fn []
        (run! session key
              {:duration-ms duration-ms
               :steps (math.max 1 (math.ceil (/ (math.max 1 delta) stride)))
               :active? (fn [] (vim.api.nvim_win_is_valid win))
               :tick! (fn [_ idx]
                        (let [next-height (if (= idx 0)
                                              start
                                              (+ start (* idx stride direction)))
                              height (if (> direction 0)
                                         (math.min stop next-height)
                                         (math.max stop next-height))]
                          (pcall vim.api.nvim_win_set_height win height)
                          (when-let [tick! (. opts :tick!)]
                            (tick! height idx))))
               :done! (fn []
                        (pcall vim.api.nvim_win_set_height win stop)
                        (when-let [done! (. opts :done!)]
                          (done! stop)))})))))

(fn animate-win-width!
  [session key win from to duration-ms opts]
  (let [start (math.max 1 from)
        stop (math.max 1 to)
        opts (or opts {})]
    (with-split-mins
      (fn []
        (run! session key
              {:duration-ms duration-ms
               :steps (math.max 2 (math.floor (/ duration-ms target-frame-ms)))
               :active? (fn [] (vim.api.nvim_win_is_valid win))
               :tick! (fn [t]
                        (let [width (math.max 1 (math.floor (+ 0.5 (lerp start stop t))))]
                          (pcall vim.api.nvim_win_set_width win width)
                          (when-let [tick! (. opts :tick!)]
                            (tick! width t))))
               :done! (fn []
                        (pcall vim.api.nvim_win_set_width win stop)
                        (when-let [done! (. opts :done!)]
                          (done! stop)))})))))

(fn animate-float!
  [session key win from-cfg to-cfg from-blend to-blend duration-ms]
  (run! session key
        {:duration-ms duration-ms
         :steps (math.max 2 (math.floor (/ duration-ms target-frame-ms)))
         :active? (fn [] (vim.api.nvim_win_is_valid win))
         :tick! (fn [t]
                  (let [cfg {:relative (. to-cfg :relative)
                             :anchor (. to-cfg :anchor)
                             :row (lerp (or (. from-cfg :row) (. to-cfg :row))
                                        (. to-cfg :row)
                                        t)
                             :col (lerp (or (. from-cfg :col) (. to-cfg :col))
                                        (. to-cfg :col)
                                        t)
                             :width (math.max 1 (math.floor (+ 0.5 (lerp (or (. from-cfg :width) (. to-cfg :width))
                                                                          (. to-cfg :width)
                                                                          t))))
                             :height (math.max 1 (math.floor (+ 0.5 (lerp (or (. from-cfg :height) (. to-cfg :height))
                                                                           (. to-cfg :height)
                                                                           t))))
                             :style "minimal"}
                        _ (when-let [host (. to-cfg :win)]
                            (set (. cfg :win) host))
                        blend (math.max 0 (math.min 100 (math.floor (+ 0.5 (lerp from-blend to-blend t)))))]
                    (pcall vim.api.nvim_win_set_config win cfg)
                    (pcall vim.api.nvim_set_option_value "winblend" blend {:win win})))
         :done! (fn []
                  (pcall vim.api.nvim_win_set_config win to-cfg)
                  (pcall vim.api.nvim_set_option_value "winblend" to-blend {:win win}))}))

(fn animate-view!
  [session key win from-view to-view duration-ms]
  (run! session key
        {:duration-ms duration-ms
         :steps (math.max 2 (math.floor (/ duration-ms target-frame-ms)))
         :active? (fn [] (vim.api.nvim_win_is_valid win))
         :tick! (fn [t]
                  (vim.api.nvim_win_call
                    win
                    (fn []
                      (pcall vim.fn.winrestview
                             {:topline (math.max 1 (math.floor (+ 0.5 (lerp (or (. from-view :topline) 1)
                                                                             (or (. to-view :topline) 1)
                                                                             t))))
                              :lnum (math.max 1 (math.floor (+ 0.5 (lerp (or (. from-view :lnum) 1)
                                                                          (or (. to-view :lnum) 1)
                                                                          t))))
                              :leftcol (math.max 0 (math.floor (+ 0.5 (lerp (or (. from-view :leftcol) 0)
                                                                              (or (. to-view :leftcol) 0)
                                                                              t))))
                              :col (math.max 0 (math.floor (+ 0.5 (lerp (or (. from-view :col) 0)
                                                                         (or (. to-view :col) 0)
                                                                         t))))}))))
         :done! (fn []
                  (vim.api.nvim_win_call
                    win
                    (fn []
                      (pcall vim.fn.winrestview to-view))))}))

(set M.enabled? enabled?)
(set M.duration-ms duration-ms)
(set M.run! run!)
(set M.animate-win-height! animate-win-height!)
(set M.animate-win-height-stepwise! animate-win-height-stepwise!)
(set M.animate-win-width! animate-win-width!)
(set M.animate-float! animate-float!)
(set M.animate-view! animate-view!)

M
