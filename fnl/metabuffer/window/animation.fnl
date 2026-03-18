(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})
(local target-frame-ms 17)
(var mini-animate-cache nil)
(var mini-animate-tried? false)

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

(fn ease-in-out-cubic
  [t]
  (let [x (math.max 0 (math.min t 1))]
    (if (< x 0.5)
        (* 4 x x x)
        (let [y (- (* 2 x) 2)]
          (+ 1 (/ (* y y y) 2))))))

(fn lerp
  [a b t]
  (+ a (* (- b a) t)))

(fn number-or
  [v fallback]
  (if (= (type v) "number") v fallback))

(fn mini-animate-mod
  []
  "Load `mini.animate` once. Expected output: module table or nil."
  (when-not mini-animate-tried?
    (set mini-animate-tried? true)
    (let [[ok mod] [(pcall require :mini.animate)]]
      (set mini-animate-cache (if ok mod false))))
  (if (= mini-animate-cache false) nil mini-animate-cache))

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

(fn scroll-backend
  [session]
  "Return configured scroll backend. Expected output: \"native\" or \"mini\"."
  (let [settings (or session.animation-settings {})
        entry (or (. settings :scroll) {})
        backend (. entry :backend)]
    (if (= backend "mini") "mini" "native")))

(fn supports-scroll-backend?
  [backend]
  "Return whether scroll backend is usable in current runtime."
  (if (= backend "mini")
      (not (not (mini-animate-mod)))
      true))

(fn run!
  [session key opts]
  (let [{: steps : tick! : done! : active?} opts
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
                (let [t (ease-in-out-cubic (/ idx total))]
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
  [session key win from-cfg to-cfg from-blend to-blend duration-ms opts]
  (let [opts (or opts {})]
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
                      (pcall vim.api.nvim_set_option_value "winblend" blend {:win win})
                      (when-let [tick! (. opts :tick!)]
                        (tick! cfg t))))
           :done! (fn []
                    (pcall vim.api.nvim_win_set_config win to-cfg)
                    (pcall vim.api.nvim_set_option_value "winblend" to-blend {:win win})
                    (when-let [done! (. opts :done!)]
                      (done! to-cfg)))})))

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

(fn animate-scroll-view-mini!
  [session key win from-view to-view duration-ms]
  "Animate vertical results scrolling with `mini.animate` timing/subscroll helpers."
  (let [mini (mini-animate-mod)
        from-top (or (. from-view :topline) 1)
        to-top (or (. to-view :topline) from-top)
        total-scroll (math.abs (- to-top from-top))
        subscroll-fn ((. (. mini :gen_subscroll) :equal)
                      {:predicate (fn [n] (> n 1))
                       :max_output_steps 60})
        step-scrolls (subscroll-fn total-scroll)
        n-steps (# step-scrolls)]
    (if (or (<= total-scroll 0) (<= n-steps 0))
        (vim.api.nvim_win_call
          win
          (fn []
            (pcall vim.fn.winrestview to-view)))
        (let [token (next-token! session key)
              timing ((. (. mini :gen_timing) :cubic)
                      {:easing "in-out"
                       :duration duration-ms
                       :unit "total"})
              dir (if (< from-top to-top) 1 -1)
              from-lnum (or (. from-view :lnum) from-top)
              to-lnum (or (. to-view :lnum) to-top)
              scrolled0 0]
          (var scrolled scrolled0)
          ((. mini :animate)
           (fn [step]
             (if (or (not (active-token? session key token))
                     (not (vim.api.nvim_win_is_valid win)))
                 false
                 (do
                   (when (> step 0)
                     (set scrolled (+ scrolled (or (. step-scrolls step) 0)))
                     (let [coef (/ step n-steps)
                           target {:topline (+ from-top (* dir scrolled))
                                   :lnum (math.max 1 (math.floor (+ 0.5 (lerp from-lnum to-lnum coef))))
                                   :leftcol (or (. to-view :leftcol) (. from-view :leftcol) 0)
                                   :col (or (. to-view :col) (. from-view :col) 0)}]
                       (vim.api.nvim_win_call
                         win
                         (fn []
                           (pcall vim.fn.winrestview target)))))
                   (if (< step n-steps)
                       true
                       (do
                         (vim.api.nvim_win_call
                           win
                           (fn []
                             (pcall vim.fn.winrestview to-view)))
                         false)))))
           (fn [step]
             (timing step n-steps))
           {:max_steps (+ n-steps 1)})))))

(fn animate-scroll-view!
  [session key win from-view to-view duration-ms]
  "Animate scroll view with configured backend and native fallback."
  (if (and (= (scroll-backend session) "mini")
           (supports-scroll-backend? "mini"))
      (animate-scroll-view-mini! session key win from-view to-view duration-ms)
      (animate-view! session key win from-view to-view duration-ms)))

(set M.enabled? enabled?)
(set M.duration-ms duration-ms)
(set M.scroll-backend scroll-backend)
(set M.supports-scroll-backend? supports-scroll-backend?)
(set M.with-split-mins with-split-mins)
(set M.run! run!)
(set M.animate-win-height! animate-win-height!)
(set M.animate-win-height-stepwise! animate-win-height-stepwise!)
(set M.animate-win-width! animate-win-width!)
(set M.animate-float! animate-float!)
(set M.animate-view! animate-view!)
(set M.animate-scroll-view! animate-scroll-view!)

M
