(require-macros :io.gitlab.andreyorst.cljlib.core)

(local M {})
(local target-frame-ms 17)
(var mini-animate-cache nil)
(var mini-animate-tried? false)
(var mini-animate-scoped? false)
(var mark-mini-session! nil)
(var unmark-mini-session! nil)
(var execute-after! nil)

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
  "Load `mini.animate` as a helper library, without calling global setup.
Expected output: module table or nil."
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
      (set vim.o.winminwidth old-width) ; test
      (set vim.o.equalalways old-equalalways)
      (cond-> res (not ok) error))))

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

(fn animation-backend
  [session kind]
  "Return configured backend for animation kind. Expected output: \"native\" or \"mini\"."
  (let [settings (or session.animation-settings {})
        entry (or (. settings kind) {})
        backend (or (. entry :backend) (. settings :backend))]
    (if (= backend "mini") "mini" "native")))

(fn supports-backend?
  [backend]
  "Return whether scroll backend is usable in current runtime."
  (if (= backend "mini")
      (not (not (mini-animate-mod)))
      true))

(fn mini-autocmds-present?
  []
  (let [[ok acs] [(pcall vim.api.nvim_get_autocmds {:group "MiniAnimate"})]]
    (and ok (> (# (or acs [])) 0))))

(fn mini-managed-buf?
  [buf]
  (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "metabuffer_minianimate_enable")]]
    (and ok (not (not v)))))

(fn apply-mini-scope!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (if (mini-managed-buf? buf)
        (do
          (pcall vim.api.nvim_buf_set_var buf "minianimate_disable" false)
          (let [[ok cfg] [(pcall vim.api.nvim_buf_get_var buf "metabuffer_minianimate_config")]]
            (when ok
              (pcall vim.api.nvim_buf_set_var buf "minianimate_config" cfg))))
        (pcall vim.api.nvim_buf_set_var buf "minianimate_disable" true))))

(fn ensure-mini-scope!
  []
  (when-not mini-animate-scoped?
    (set mini-animate-scoped? true)
    (let [group (vim.api.nvim_create_augroup "MetabufferMiniAnimateScope" {:clear true})
          apply! (fn [ev]
                   (apply-mini-scope! (. ev :buf)))]
      (vim.api.nvim_create_autocmd ["BufEnter" "BufWinEnter"]
                                   {:group group
                                    :callback apply!}))))

(fn ensure-mini-global!
  [session]
  "Ensure `mini.animate` is set up once for Meta-scoped usage.
Expected output: module table or nil."
  (let [mini (mini-animate-mod)]
    (when mini
      (when-not (mini-autocmds-present?)
        (mini.setup {:cursor {:enable true
                              :timing ((. (. mini :gen_timing) :cubic)
                                       {:easing "in-out"
                                        :duration 100
                                        :unit "total"})}
                     :scroll {:enable true}
                     :resize {:enable true}
                     :open {:enable false}
                     :close {:enable false}}))
      (ensure-mini-scope!)
      (when session
        (mark-mini-session! session)))
    mini))

(fn mini-timing
  [mini duration-ms n-steps]
  (let [timing ((. (. mini :gen_timing) :cubic)
                {:easing "in-out"
                 :duration duration-ms
                 :unit "total"})]
    (fn [step]
      (timing step n-steps))))

(fn once
  [f]
  "Wrap callback so it can only run once. Expected output: function."
  (let [called0 false]
    (var called called0)
    (fn [...]
      (when-not called
        (set called true)
        (f ...)))))

(fn restore-window-focus!
  [return-win return-mode]
  "Restore focus/mode after temporary Mini-owned window actions."
  (when (and return-win (vim.api.nvim_win_is_valid return-win))
    (pcall vim.api.nvim_set_current_win return-win)
    (when (and (= (type return-mode) "string")
               (vim.startswith return-mode "i"))
      (pcall vim.cmd "startinsert"))))

(fn mini-run!
  [mini session key n-steps duration-ms active? step-action]
  "Run `mini.animate` with Meta-owned cancellation/state handling.
Expected output: nil."
  (let [token (next-token! session key)
        timing (mini-timing mini duration-ms n-steps)]
    ((. mini :animate)
     (fn [step]
       (if (or (not (active-token? session key token))
               (and active? (not (active?))))
           false
           (step-action step)))
     timing
     {:max_steps (+ n-steps 1)})))

(fn mini-float-winblend-fn
  [mini from-blend to-blend]
  "Build float winblend interpolation from `mini.animate`.
Expected output: function."
  ((. (. mini :gen_winblend) :linear)
   {:from from-blend
    :to to-blend}))

(fn mini-after!
  [animation-type delay-ms action]
  "Run action after Mini animation finishes, with time fallback. Expected output: nil."
  (let [run! (once action)]
    (execute-after! animation-type run!)
    (vim.defer_fn run! (math.max 0 (+ (or delay-ms 0) 24)))))

(fn mini-buffer-config
  [session]
  "Build buffer-local `mini.animate` config for Meta buffers.
Expected output: config table."
  (let [mini (mini-animate-mod)]
    {:cursor {:enable true
              :timing ((. (. mini :gen_timing) :cubic)
                       {:easing "in-out"
                        :duration 100
                        :unit "total"})}
     :scroll {:enable (enabled? session :scroll)
              :timing ((. (. mini :gen_timing) :cubic)
                       {:easing "in-out"
                        :duration (duration-ms session :scroll 100)
                        :unit "total"})
              :subscroll ((. (. mini :gen_subscroll) :equal)
                          {:predicate (fn [n] (> n 1))
                           :max_output_steps 60})}
     :resize {:enable (enabled? session :prompt)
              :timing ((. (. mini :gen_timing) :cubic)
                       {:easing "in-out"
                        :duration (duration-ms session :prompt 140)
                        :unit "total"})
              :subresize ((. (. mini :gen_subresize) :equal))}
     :open {:enable false}
     :close {:enable false}}))

(set mark-mini-session!
  (fn [session]
    (when (and session (supports-backend? "mini"))
      (let [cfg (mini-buffer-config session)]
        (each [_ buf (ipairs [(and session.meta session.meta.buf session.meta.buf.buffer)
                              session.prompt-buf
                              session.info-buf])]
          (when (and buf (vim.api.nvim_buf_is_valid buf))
            (pcall vim.api.nvim_buf_set_var buf "metabuffer_minianimate_enable" true)
            (pcall vim.api.nvim_buf_set_var buf "metabuffer_minianimate_config" cfg)
            (apply-mini-scope! buf)))))))

(set unmark-mini-session!
  (fn [session]
    (when session
      (each [_ buf (ipairs [(and session.meta session.meta.buf session.meta.buf.buffer)
                            session.prompt-buf
                            session.info-buf])]
        (when (and buf (vim.api.nvim_buf_is_valid buf))
          (pcall vim.api.nvim_buf_del_var buf "metabuffer_minianimate_enable")
          (pcall vim.api.nvim_buf_del_var buf "metabuffer_minianimate_config")
          (pcall vim.api.nvim_buf_set_var buf "minianimate_disable" true))))))

(set execute-after!
  (fn [animation-type action]
    (let [mini (mini-animate-mod)]
      (if mini
          (mini.execute_after animation-type action)
          (action)))))

(fn set-win-height!
  [win height]
  (pcall vim.api.nvim_win_set_height win (math.max 1 height)))

(fn float-step-config
  [from-cfg to-cfg t]
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
             :style "minimal"}]
    (when-let [host (. to-cfg :win)]
      (set (. cfg :win) host))
    cfg))

(fn apply-float-step!
  [win cfg blend opts step]
  (pcall vim.api.nvim_win_set_config win cfg)
  (pcall vim.api.nvim_set_option_value "winblend" blend {:win win})
  (when-let [tick! (. opts :tick!)]
    (tick! cfg step)))

(var animate-win-width! nil)
(var animate-float! nil)
(var animate-view! nil)
(var animate-scroll-action-mini! nil)
(var animate-scroll-view-mini! nil)
(var animate-scroll-view! nil)

(fn run!
  [session key opts]
  (let [{: steps : tick! : done! : active?} opts
        token (next-token! session key)
        total (math.max 1 (or steps 1))
        wait (math.max 8 target-frame-ms)
        last-frame-ms0 nil]
    (var last-frame-ms last-frame-ms0)
    (fn frame!
      [idx]
      (when (and (active-token? session key token)
                 (or (not active?) (active?)))
        (let [now (now-ms)
              elapsed (if last-frame-ms (- now last-frame-ms) wait)]
          (if (< elapsed wait)
              (vim.defer_fn (fn [] (frame! idx)) (- wait elapsed))
              (do
                (set last-frame-ms now)
                (let [t (ease-in-out-cubic (/ idx total))]
                  (tick! t idx total)
                  (if (< idx total)
                      (vim.defer_fn (fn [] (frame! (+ idx 1))) wait)
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
    (if (and (= (animation-backend session :prompt) "mini")
             (supports-backend? "mini"))
        (do
          (ensure-mini-global! session)
          (with-split-mins
            (fn []
              (set-win-height! win stop)
              (mini-after!
                "resize"
                duration-ms
                (fn []
                  (when-let [done! (. opts :done!)]
                    (done! stop)))))))
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
                              (set-win-height! win height)
                              (when-let [tick! (. opts :tick!)]
                                (tick! height idx))))
                   :done! (fn []
                            (set-win-height! win stop)
                            (when-let [done! (. opts :done!)]
                              (done! stop)))}))))))

(set animate-win-width!
  (fn [session key win from to duration-ms opts]
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
                            (done! stop)))}))))))

(set animate-float!
  (fn [session key win from-cfg to-cfg from-blend to-blend duration-ms opts]
    (let [opts (or opts {})
          kind (or (. opts :kind) :info)]
      (if (and (= (animation-backend session kind) "mini")
               (supports-backend? "mini"))
          (let [mini (mini-animate-mod)
                n-steps (math.max 2 (math.floor (/ duration-ms target-frame-ms)))
                blend-fn (mini-float-winblend-fn mini from-blend to-blend)]
            (mini-run!
              mini
              session
              key
              n-steps
              duration-ms
              (fn [] (vim.api.nvim_win_is_valid win))
              (fn [step]
                (let [t (/ step n-steps)
                      cfg (float-step-config from-cfg to-cfg t)
                      blend (math.max 0 (math.min 100 (blend-fn step n-steps)))]
                  (apply-float-step! win cfg blend opts t)
                  (if (< step n-steps)
                      true
                      (do
                        (apply-float-step! win to-cfg to-blend opts 1.0)
                        (when-let [done! (. opts :done!)]
                          (done! to-cfg))
                        false))))))
          (run! session key
                {:duration-ms duration-ms
                 :steps (math.max 2 (math.floor (/ duration-ms target-frame-ms)))
                 :active? (fn [] (vim.api.nvim_win_is_valid win))
                 :tick! (fn [t]
                          (let [cfg (float-step-config from-cfg to-cfg t)
                                blend (math.max 0 (math.min 100 (math.floor (+ 0.5 (lerp from-blend to-blend t)))))]
                            (apply-float-step! win cfg blend opts t)))
                 :done! (fn []
                          (apply-float-step! win to-cfg to-blend opts 1.0)
                          (when-let [done! (. opts :done!)]
                            (done! to-cfg)))})))))

(set animate-view!
  (fn [session key win from-view to-view duration-ms opts]
    (let [opts (or opts {})]
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
                        (pcall vim.fn.winrestview to-view)))
                    (when-let [done! (. opts :done!)]
                      (done! to-view)))}))))

(set animate-scroll-action-mini!
  (fn [session win duration-ms action opts]
    "Run a real scroll action inside window context and let Mini animate it."
    (let [opts (or opts {})
          token (next-token! session :mini-scroll-focus)
          return-win (. opts :return-win)
          return-mode (. opts :return-mode)
          done! (. opts :done!)
          active? (fn [] (active-token? session :mini-scroll-focus token))
          finish! (once
                    (fn []
                      (when (active?)
                        (restore-window-focus! return-win return-mode)
                        (when done!
                          (done!)))))]
      (ensure-mini-global! session)
      (when (and (= (type return-mode) "string")
                 (vim.startswith return-mode "i"))
        (pcall vim.cmd "stopinsert"))
      (pcall vim.api.nvim_set_current_win win)
      (vim.schedule
        (fn []
          (if (and (active?) (vim.api.nvim_win_is_valid win))
              (do
                (pcall vim.api.nvim_set_current_win win)
                (action)
                (mini-after! "scroll" duration-ms finish!))
              (finish!)))))))

(set animate-scroll-view-mini!
  (fn [session _key win _from-view to-view duration-ms opts]
    "Fallback Mini path for externally supplied target view."
    (animate-scroll-action-mini!
      session
      win
      duration-ms
      (fn []
        (pcall vim.fn.winrestview to-view))
      opts)))

(set animate-scroll-view!
  (fn [session key win from-view to-view duration-ms opts]
    "Animate scroll view with configured backend and native fallback."
    (if (and (= (animation-backend session :scroll) "mini")
             (supports-backend? "mini"))
        (animate-scroll-view-mini! session key win from-view to-view duration-ms opts)
        (animate-view! session key win from-view to-view duration-ms opts))))

(fn reset-mini-animate-cache!
  []
  "Reset cached `mini.animate` module lookup. Expected output: nil."
  (set mini-animate-cache nil)
  (set mini-animate-tried? false))

(set M.enabled? enabled?)
(set M.duration-ms duration-ms)
(set M.animation-backend animation-backend)
(set M.scroll-backend (fn [session] (animation-backend session :scroll)))
(set M.supports-backend? supports-backend?)
(set M.supports-scroll-backend? supports-backend?)
(set M.ensure-mini-global! ensure-mini-global!)
(set M.mark-mini-session! mark-mini-session!)
(set M.unmark-mini-session! unmark-mini-session!)
(set M.with-split-mins with-split-mins)
(set M.run! run!)
(set M.animate-win-height! animate-win-height!)
(set M.animate-win-height-stepwise! animate-win-height-stepwise!)
(set M.animate-win-width! animate-win-width!)
(set M.animate-float! animate-float!)
(set M.animate-view! animate-view!)
(set M.animate-scroll-view! animate-scroll-view!)
(set M.animate-scroll-action-mini! animate-scroll-action-mini!)
(set M.reset-mini-animate-cache! reset-mini-animate-cache!)

M
