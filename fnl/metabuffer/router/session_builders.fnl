(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local M {})

(fn M.new
  [opts]
  "Build session-state construction helpers."
  (let [{: history-store : query-mod : router-util-mod : prompt-window-mod} (or opts {})]
    (fn build-animation-settings
      [ui-animation fast-test-startup?]
      (let [ui-animation-prompt (. ui-animation :prompt)
            ui-animation-preview (. ui-animation :preview)
            ui-animation-info (. ui-animation :info)
            ui-animation-loading (. ui-animation :loading)
            ui-animation-scroll (. ui-animation :scroll)]
        {:enabled (and (not fast-test-startup?)
                       (not (= false (. ui-animation :enabled))))
         :backend (or (. ui-animation :backend) "native")
         :time-scale (or (. ui-animation :time-scale) 1.0)
         :prompt {:enabled (not (= false (. ui-animation-prompt :enabled)))
                  :ms (. ui-animation-prompt :ms)
                  :time-scale (or (. ui-animation-prompt :time-scale) 1.0)
                  :backend (or (. ui-animation-prompt :backend) "native")}
         :preview {:enabled (not (= false (. ui-animation-preview :enabled)))
                   :ms (. ui-animation-preview :ms)
                   :time-scale (or (. ui-animation-preview :time-scale) 1.0)}
         :info {:enabled (not (= false (. ui-animation-info :enabled)))
                :ms (. ui-animation-info :ms)
                :time-scale (or (. ui-animation-info :time-scale) 1.0)
                :backend (or (. ui-animation-info :backend) "native")}
         :loading {:enabled (not (= false (. ui-animation-loading :enabled)))
                   :ms (. ui-animation-loading :ms)
                   :time-scale (or (. ui-animation-loading :time-scale) 1.0)}
         :scroll {:enabled (not (= false (. ui-animation-scroll :enabled)))
                  :ms (. ui-animation-scroll :ms)
                  :time-scale (or (. ui-animation-scroll :time-scale) 1.0)
                  :backend (or (. ui-animation-scroll :backend) "native")}}))

    (fn prompt-animates?
      [ui-animation fast-test-startup?]
      (and (not fast-test-startup?)
           (. ui-animation :enabled)
           (not (= false (. (. ui-animation :prompt) :enabled)))))

    (fn prompt-start-height
      [prompt-animates?]
      (if prompt-animates?
          1
          (router-util-mod.prompt-height)))

    (fn build-prompt-window
      [settings origin-win prompt-animates?]
      (prompt-window-mod.new
        vim
        {:height (router-util-mod.prompt-height)
         :start-height (prompt-start-height prompt-animates?)
         :floating? prompt-animates?
         :window-local-layout settings.window-local-layout
         :origin-win origin-win}))

    (fn build-last-parsed-query
      [parsed-query start-hidden start-ignored start-deps start-binary start-files start-prefilter start-lazy start-expansion start-transforms]
      (vim.tbl_extend
        "force"
        {:lines (or (. parsed-query :lines) [""])
         :lgrep-lines (or (. parsed-query :lgrep-lines) [])
         :include-hidden start-hidden
         :include-ignored start-ignored
         :include-deps start-deps
         :include-binary start-binary
         :include-files start-files
         :file-lines (or (. parsed-query :file-lines) [])
         :prefilter start-prefilter
         :lazy start-lazy
         :expansion start-expansion}
        (transform-mod.compat-view start-transforms)))

    (fn startup-ui-delay-ms
      [animation-settings ui-animation]
      (let [settings0 (or animation-settings {})
            global-enabled? (and (. ui-animation :enabled) (not (= false (. settings0 :enabled))))
            global-scale (or (. settings0 :time-scale) 1.0)
            prompt-settings (or (. settings0 :prompt) {})
            info-settings (or (. settings0 :info) {})
            prompt-ms (if (and global-enabled? (not (= false (. prompt-settings :enabled))))
                          (math.max 0 (math.floor (+ 0.5 (* (or (. prompt-settings :ms) 140)
                                                             global-scale
                                                             (or (. prompt-settings :time-scale) 1.0)))))
                          0)
            info-ms (if (and global-enabled? (not (= false (. info-settings :enabled))))
                        (math.max 0 (math.floor (+ 0.5 (* (or (. info-settings :ms) 220)
                                                           global-scale
                                                           (or (. info-settings :time-scale) 1.0)))))
                        0)]
        (math.max prompt-ms info-ms)))

    (fn build-prompt-session-state
      [settings prompt-win prompt-buf initial-lines parsed-query animation-settings ui-animation ui fast-test-startup?]
      (let [prompt-text (table.concat initial-lines "\n")]
        {:prompt-window prompt-win
         :prompt-win prompt-win.window
         :prompt-target-height (router-util-mod.prompt-height)
         :prompt-buf prompt-buf
         :prompt-floating? prompt-win.floating?
         :window-local-layout settings.window-local-layout
         :prompt-keymaps settings.prompt-keymaps
         :main-keymaps settings.main-keymaps
         :prompt-fallback-keymaps settings.prompt-fallback-keymaps
         :info-file-entry-view (or settings.info-file-entry-view "meta")
         :initial-prompt-text prompt-text
         :last-prompt-text prompt-text
         :last-history-text ""
         :history-index 0
         :history-cache (vim.deepcopy (history-store.list))
         :prompt-update-pending false
         :prompt-update-dirty false
         :prompt-change-seq 0
         :prompt-last-apply-ms 0
         :prompt-last-event-text prompt-text
         :initial-query-active (query-mod.query-lines-has-active? (. parsed-query :lines))
         :startup-initializing true
         :prompt-animating? false
         :animate-enter? (and (not fast-test-startup?)
                              (clj.boolean (. ui-animation :enabled)))
         :startup-ui-delay-ms (startup-ui-delay-ms animation-settings ui-animation)
         :loading-indicator? (clj.boolean (. ui :loading-indicator))
         :animation-settings animation-settings}))

    (fn build-project-session-state
      [settings parsed-query project-mode start-hidden start-ignored start-deps start-binary start-files start-prefilter start-lazy start-expansion start-transforms]
      {:project-mode (or project-mode false)
       :project-mode-starting? (clj.boolean project-mode)
       :include-hidden start-hidden
       :include-ignored start-ignored
       :include-deps start-deps
       :include-binary start-binary
       :include-files start-files
       :default-include-lgrep (query-mod.truthy? settings.default-include-lgrep)
       :effective-include-hidden start-hidden
       :effective-include-ignored start-ignored
       :effective-include-deps start-deps
       :effective-include-binary start-binary
       :effective-include-files start-files
       :transform-flags (vim.deepcopy start-transforms)
       :effective-transforms (vim.deepcopy start-transforms)
       :active-source-key (source-mod.query-source-key parsed-query)
       :project-bootstrap-pending false
       :project-bootstrap-token 0
       :project-bootstrap-delay-ms (if (query-mod.query-lines-has-active? (. parsed-query :lines))
                                       settings.project-bootstrap-delay-ms
                                       settings.project-bootstrap-idle-delay-ms)
       :project-bootstrapped (not (or project-mode false))
       :prefilter-mode start-prefilter
       :lazy-mode start-lazy
       :expansion-mode start-expansion
       :project-source-syntax-chunk-lines settings.project-source-syntax-chunk-lines
       :project-lazy-refresh-min-ms settings.project-lazy-refresh-min-ms
       :project-lazy-refresh-debounce-ms settings.project-lazy-refresh-debounce-ms
       :last-parsed-query (build-last-parsed-query
                            parsed-query
                            start-hidden
                            start-ignored
                            start-deps
                            start-binary
                            start-files
                            start-prefilter
                            start-lazy
                            start-expansion
                            start-transforms)
       :file-query-lines (or (. parsed-query :file-lines) [])})

    (fn build-session-state
      [deps curr source-buf origin-win origin-buf source-view condition prompt-win prompt-buf initial-lines parsed-query project-mode
       start-hidden start-ignored start-deps start-binary start-files start-prefilter start-lazy start-expansion start-transforms fast-test-startup?]
      (let [ui (. deps :ui)
            ui-animation (. ui :animation)
            next-instance-id! (. deps :next-instance-id!)
            animation-settings (build-animation-settings ui-animation fast-test-startup?)
            settings (. deps :router)]
        (vim.tbl_extend
          "force"
          {:source-buf source-buf
           :origin-win origin-win
           :origin-buf origin-buf
           :source-view source-view
           :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
           :read-file-lines-cached (. deps :read-file-lines-cached)
           :single-content (vim.deepcopy curr.buf.content)
           :single-refs (vim.deepcopy (or curr.buf.source-refs []))
           :instance-id (next-instance-id!)
           :meta curr}
          (build-prompt-session-state
            settings
            prompt-win
            prompt-buf
            initial-lines
            parsed-query
            animation-settings
            ui-animation
            ui
            fast-test-startup?)
          (build-project-session-state
            settings
            parsed-query
            project-mode
            start-hidden
            start-ignored
            start-deps
            start-binary
            start-files
            start-prefilter
            start-lazy
            start-expansion
            start-transforms))))

    {:build-prompt-window build-prompt-window
     :build-session-state build-session-state
     :prompt-animates? prompt-animates?}))

M
