(local highlight-util (require :metabuffer.highlight_util))
(local events (require :metabuffer.events))
(local M {})

(fn M.new
  [opts]
  "Build shared loading-state helpers."
  (let [{: session-prompt-valid? : animation-enabled? : animation-duration-ms
         : refresh-prompt-highlights!} opts
        hl-rendered-bg (. highlight-util :hl-rendered-bg)
        darken-rgb (. highlight-util :darken-rgb)
        brighten-rgb (. highlight-util :brighten-rgb)
        copy-highlight-with-bg (. highlight-util :copy-highlight-with-bg)]
    (fn session-busy?
      [session]
      (and session
           (or session.prompt-update-pending
               session.prompt-update-dirty
               session.project-bootstrap-pending
               (and session.project-mode
                    (not session.lazy-stream-done))
               (and session.project-mode
                    (not session.project-bootstrapped)))))

    (fn session-actually-idle?
      [session]
      (and session
           (not (session-busy? session))
           (not session.prompt-update-dirty)))

    (fn results-pulse-bg
      [step]
      (let [[ok-middle middle] [(pcall vim.api.nvim_get_hl 0 {:name "MetaStatuslineMiddle" :link false})]
            [ok-status status] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
            base (or (and ok-middle (= (type middle) "table") (hl-rendered-bg middle))
                     (and ok-status (= (type status) "table") (hl-rendered-bg status))
                     0x2a2a2a)]
        (if (= step 2)
            (or (brighten-rgb base 0.02) base)
            (= step 3)
            (or (brighten-rgb base 0.04) base)
            (= step 4)
            (or (brighten-rgb base 0.06) base)
            (= step 5)
            (or (brighten-rgb base 0.04) base)
            (= step 6)
            (or (brighten-rgb base 0.02) base)
            (= step 7)
            (or (darken-rgb base 0.02) base)
            (= step 8)
            (or (darken-rgb base 0.04) base)
            (= step 9)
            (or (brighten-rgb base 0.06) base)
            (= step 10)
            (or (brighten-rgb base 0.04) base)
            (= step 11)
            (or (darken-rgb base 0.02) base)
            base)))

    (fn pulse-hl-from
      [group bg]
      (copy-highlight-with-bg group bg))

    (fn update-results-loading-pulse-highlights!
      [step]
      (let [bg (results-pulse-bg step)
            hi vim.api.nvim_set_hl]
        (hi 0 "MetaStatuslineMiddlePulse" (pulse-hl-from "MetaStatuslineMiddle" bg))
        (hi 0 "MetaStatuslineIndicatorPulse" (pulse-hl-from "MetaStatuslineIndicator" bg))
        (hi 0 "MetaStatuslineKeyPulse" (pulse-hl-from "MetaStatuslineKey" bg))
        (hi 0 "MetaStatuslineFlagOnPulse" (pulse-hl-from "MetaStatuslineFlagOn" bg))
        (hi 0 "MetaStatuslineFlagOffPulse" (pulse-hl-from "MetaStatuslineFlagOff" bg))))

    (fn set-results-loading-pulse!
      [session]
      (if (and session session.loading-anim-phase)
          (let [step (+ (% (or session.loading-anim-phase 0) 8) 1)]
            (set session.results-statusline-pulse-active? true)
            (update-results-loading-pulse-highlights! step))
          (set session.results-statusline-pulse-active? nil)))

    (var schedule-loading-indicator! nil)

    (fn loading-indicator-tick!
      [session]
      (set session.loading-anim-pending false)
      (when (session-prompt-valid? session)
        (let [animating? (and (session-busy? session)
                              animation-enabled?
                              (animation-enabled? session :loading))]
          (if animating?
              (do
                (set session.loading-idle-pending false)
                (set session.loading-anim-phase (+ 1 (or session.loading-anim-phase 0)))
                (set-results-loading-pulse! session)
                (events.send :on-loading-state!
                             {:session session})
                (refresh-prompt-highlights! session)
                (schedule-loading-indicator! session))
              (if session.loading-anim-phase
                  (if session.loading-idle-pending
                      (when (session-actually-idle? session)
                        (set session.loading-idle-pending false)
                        (set session.loading-anim-phase nil)
                        (set-results-loading-pulse! session)
                        (events.send :on-loading-state!
                                     {:session session}))
                      (do
                        (set session.loading-idle-pending true)
                        (schedule-loading-indicator! session)))
                  (do
                    (set session.loading-idle-pending false)
                    (set-results-loading-pulse! session)))))))

    (set schedule-loading-indicator!
      (fn [session]
        (when (and session
                   (not session.loading-anim-pending)
                   session.prompt-buf
                   (session-prompt-valid? session)
                   session.loading-indicator?
                   (or (session-busy? session)
                       session.loading-anim-phase
                       session.loading-idle-pending))
          (when (and (session-busy? session)
                     (= session.loading-anim-phase nil))
            (set session.loading-idle-pending false)
            (set session.loading-anim-phase 0)
            (set-results-loading-pulse! session)
            (events.send :on-loading-state!
                         {:session session}))
          (set session.loading-anim-pending true)
          (let [delay (if session.loading-idle-pending
                          120
                          (animation-duration-ms session :loading 90))]
            (vim.defer_fn
              (fn [] (loading-indicator-tick! session))
              delay)))))

    {:session-busy? session-busy?
     :session-actually-idle? session-actually-idle?
     :schedule-loading-indicator! schedule-loading-indicator!}))

M
