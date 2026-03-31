(local M {})
(local animation-mod (require :metabuffer.window.animation))
(local events (require :metabuffer.events))

(fn M.new
  [opts]
  "Build generic prompt-hook session helpers."
  (let [{: active-by-prompt} (or opts {})
        animation-enabled? (. animation-mod :enabled?)
        animation-duration-ms (. animation-mod :duration-ms)]
    (fn prompt-animation-delay-ms
      [session]
      (if (and animation-mod
               animation-enabled?
               (animation-enabled? session :prompt))
          (animation-duration-ms session :prompt 140)
          0))

    (fn switch-mode!
      [session which]
      (let [meta session.meta]
        (fn mode-label
          [value]
          (if (= (type value) "table")
              (or (. value :name) (tostring value))
              (tostring value)))
        (let [old (mode-label ((. (. meta.mode which) :current)))]
          (meta.switch_mode which)
          (events.post :on-mode-switch!
            {:session session
             :kind which
             :old old
             :new (mode-label ((. (. meta.mode which) :current)))}
            {:supersede? true
             :dedupe-key (.. "on-mode-switch:" (tostring session.prompt-buf) ":" which)}))))

    (fn nvim-exiting?
      []
      (let [v (and vim.v (. vim.v :exiting))]
        (and (~= v nil)
             (~= v vim.NIL)
             (~= v 0)
             (~= v ""))))

    (fn session-prompt-valid?
      [session]
      (and (not (nvim-exiting?))
           session
           (not session.ui-hidden)
           (not session.closing)
           session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)
           (= (. active-by-prompt session.prompt-buf) session)))

    (fn schedule-when-valid
      [session f]
      (vim.schedule
        (fn []
          (when (session-prompt-valid? session)
            (f)))))

    (fn option-prefix
      []
      (let [p (. vim.g "meta#prefix")]
        (if (and (= (type p) "string") (~= p ""))
            p
            "#")))

    {:option-prefix option-prefix
     :prompt-animation-delay-ms prompt-animation-delay-ms
     :schedule-when-valid schedule-when-valid
     :session-prompt-valid? session-prompt-valid?
     :switch-mode! switch-mode!}))

M
