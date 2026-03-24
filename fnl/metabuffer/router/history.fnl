(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})

(fn project-setting-token
  [name enabled]
  (.. "#" (if enabled "+" "-") name))

(fn changed-setting-token
  [query-mod name enabled default-enabled]
  (let [on? (query-mod.truthy? enabled)
        default-on? (query-mod.truthy? default-enabled)]
    (when (~= on? default-on?)
      (project-setting-token name on?))))

(fn explicit-setting-present?
  [parsed key]
  (~= (. parsed key) nil))

(fn normalize-history-prompt
  [text]
  (let [parts (vim.split (or text "") "%s+" {:trimempty true})
        out []]
    (each [_ tok (ipairs parts)]
      (let [next (if (= tok "#+file")
                     "#file"
                     (= tok "#+binary")
                     "#binary"
                     (= tok "#+hex")
                     "#hex"
                     tok)]
        (table.insert out next)))
    (if (> (# out) 0)
        (table.concat out " ")
        (or text ""))))

(fn M.new
  [opts]
  (let [history-store (. opts :history-store)
        router-util-mod (. opts :router-util-mod)
        query-mod (. opts :query-mod)
        history-browser-window (. opts :history-browser-window)
        settings (. opts :settings)]
    (local api {})

    (fn api.history-entry-query
      [entry]
      (let [parsed (query-mod.parse-query-text (normalize-history-prompt entry))]
        (or (. parsed :query) "")))

    (fn api.history-entry-token
      [entry]
      (let [parts (vim.split (api.history-entry-query entry) "%s+" {:trimempty true})]
        (if (> (# parts) 0)
            (. parts (# parts))
            "")))

    (fn api.history-entry-tail
      [entry]
      (let [parts (vim.split (api.history-entry-query entry) "%s+" {:trimempty true})]
        (if (> (# parts) 1)
            (table.concat (vim.list_slice parts 2) " ")
            "")))

    (fn api.history-entry-with-settings
      [session prompt]
      (let [query-text (or prompt "")
            parsed (query-mod.parse-query-text query-text)
            seen {}
            tokens []
            _ (each [_ part (ipairs (vim.split query-text "%s+" {:trimempty true}))]
                (when (and (= (type part) "string") (~= part ""))
                  (set (. seen part) true)))
            _ (when (and session session.project-mode)
                (let [defaults settings]
                  (when-let [tok (changed-setting-token
                                   query-mod
                                   "hidden"
                                   session.effective-include-hidden
                                   defaults.default-include-hidden)]
                    (when (and (not (explicit-setting-present? parsed :include-hidden))
                               (not (. seen tok)))
                      (table.insert tokens tok)))
                  (when-let [tok (changed-setting-token
                                   query-mod
                                   "ignored"
                                   session.effective-include-ignored
                                   defaults.default-include-ignored)]
                    (when (and (not (explicit-setting-present? parsed :include-ignored))
                               (not (. seen tok)))
                      (table.insert tokens tok)))
                  (when-let [tok (changed-setting-token
                                   query-mod
                                   "deps"
                                   session.effective-include-deps
                                   defaults.default-include-deps)]
                    (when (and (not (explicit-setting-present? parsed :include-deps))
                               (not (. seen tok)))
                      (table.insert tokens tok)))
                  ;; Keep only consumed controls in synthetic history prefix.
                  ;; Non-consumed controls (#file/#binary/#hex) stay in prompt text as typed.
                  (when-let [tok (changed-setting-token
                                   query-mod
                                   "prefilter"
                                   session.prefilter-mode
                                   defaults.project-lazy-prefilter-enabled)]
                    (when (and (not (explicit-setting-present? parsed :prefilter))
                               (not (. seen tok)))
                      (table.insert tokens tok)))
                  (when-let [tok (changed-setting-token
                                   query-mod
                                   "lazy"
                                   session.lazy-mode
                                   defaults.project-lazy-enabled)]
                    (when (and (not (explicit-setting-present? parsed :lazy))
                               (not (. seen tok)))
                      (table.insert tokens tok)))))
            prefix (if (> (# tokens) 0) (table.concat tokens " ") "")]
        (if (= prefix "")
            query-text
            (if (= query-text "")
                prefix
                (.. prefix " " query-text)))))

    (fn api.push-history-entry!
      [session text]
      (history-store.push! (api.history-entry-with-settings session text) settings.history-max))

    (fn api.merge-history-into-session!
      [session]
      (let [local0 (or session.history-cache [])
            merged (vim.deepcopy local0)
            incoming (history-store.list)
            seen {}]
        (each [_ item (ipairs merged)]
          (when (= (type item) "string")
            (set (. seen item) true)))
        (each [_ item (ipairs incoming)]
          (when (and (= (type item) "string")
                     (~= (vim.trim item) "")
                     (not (. seen item)))
            (table.insert merged item)
            (set (. seen item) true)))
        (while (> (# merged) settings.history-max)
          (table.remove merged 1))
        (set session.history-cache merged)))

    (fn api.save-current-prompt-tag!
      [_session tag prompt]
      (when (and (= (type tag) "string")
                 (~= (vim.trim tag) "")
                 (= (type prompt) "string")
                 (~= (vim.trim prompt) ""))
        (history-store.save-tag! tag prompt)))

    (fn api.restore-saved-prompt-tag!
      [session tag]
      (when (and session
                 (= (type tag) "string")
                 (~= (vim.trim tag) ""))
        (when-let [saved (history-store.saved-entry tag)]
          (router-util-mod.set-prompt-text! session (normalize-history-prompt saved))
          true)))

    (fn api.history-browser-filter
      [session]
      (vim.trim (or (router-util-mod.prompt-text session) "")))

    (fn api.history-browser-items
      [session]
      (let [mode (or session.history-browser-mode "history")
            filter0 (string.lower (api.history-browser-filter session))
            out []]
        (if (= mode "saved")
            (each [_ item (ipairs (history-store.saved-items))]
              (let [tag (or (. item :tag) "")
                    prompt (normalize-history-prompt (or (. item :prompt) ""))
                    hay (string.lower (.. tag " " prompt))]
                (when (or (= filter0 "")
                          (not (not (string.find hay filter0 1 true))))
                  (table.insert out {:label (.. "##" tag "  " prompt)
                                     :prompt prompt
                                     :tag tag}))))
            (let [h (or session.history-cache (history-store.list))]
              (for [i (# h) 1 -1]
                (let [entry (normalize-history-prompt (or (. h i) ""))
                      hay (string.lower entry)]
                  (when (or (= filter0 "")
                            (not (not (string.find hay filter0 1 true))))
                    (table.insert out {:label entry :prompt entry}))))))
        out))

    (fn api.refresh-history-browser!
      [session]
      (when (and session history-browser-window session.history-browser-active)
        (set session.history-browser-filter (api.history-browser-filter session))
        (history-browser-window.refresh! session (api.history-browser-items session))))

    (fn api.close-history-browser!
      [session]
      (when history-browser-window
        (history-browser-window.close! session)))

    (fn api.open-history-browser!
      [session mode]
      (when history-browser-window
        (history-browser-window.open! session (or mode "history"))
        (api.refresh-history-browser! session)))

    (fn api.apply-history-browser-selection!
      [session]
        (when (and history-browser-window session.history-browser-active)
          (when-let [selected (history-browser-window.selected! session)]
            (when-let [prompt (. selected :prompt)]
            (router-util-mod.set-prompt-text! session (normalize-history-prompt prompt))))
        (api.close-history-browser! session)))

    (fn api.history-latest
      [session]
      (let [h (or (and session session.history-cache) (history-store.list))
            n (# h)]
        (if (> n 0) (normalize-history-prompt (. h n)) "")))

    (fn api.history-latest-token
      [session]
      (api.history-entry-token (api.history-latest session)))

    (fn api.history-latest-tail
      [session]
      (api.history-entry-tail (api.history-latest session)))

    (fn api.last-prompt-entry
      [prompt-buf active-by-prompt]
      (api.history-latest (. active-by-prompt prompt-buf)))

    (fn api.last-prompt-token
      [prompt-buf active-by-prompt]
      (api.history-latest-token (. active-by-prompt prompt-buf)))

    (fn api.last-prompt-tail
      [prompt-buf active-by-prompt]
      (api.history-latest-tail (. active-by-prompt prompt-buf)))

    (fn api.saved-prompt-entry
      [tag]
      (history-store.saved-entry tag))

    (fn api.history-or-move
      [prompt-buf delta active-by-prompt move-selection-fn]
      (let [session (. active-by-prompt prompt-buf)]
        (when session
          (if session.history-browser-active
              (history-browser-window.move! session delta)
              (let [txt (router-util-mod.prompt-text session)
                    can-history (or (= txt "")
                                    (= txt session.initial-prompt-text)
                                    (= txt session.last-history-text)
                                    (= txt (api.history-entry-query session.last-history-text)))]
                (if can-history
                    (let [h (or session.history-cache (history-store.list))
                          n (# h)]
                      (when (> n 0)
                        (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                        (if (= session.history-index 0)
                            (do
                              (set session.last-history-text "")
                              (router-util-mod.set-prompt-text! session session.initial-prompt-text))
                            (let [entry (. h (+ (- n session.history-index) 1))]
                              (when entry
                                (let [norm-entry (normalize-history-prompt entry)]
                                  (set session.last-history-text norm-entry)
                                  (router-util-mod.set-prompt-text! session norm-entry)))))))
                    (move-selection-fn prompt-buf delta)))))))

    (fn api.open-history-searchback
      [prompt-buf active-by-prompt]
      (let [session (. active-by-prompt prompt-buf)]
        (when session
          (when-not session.history-cache
            (set session.history-cache (vim.deepcopy (history-store.list))))
          (api.open-history-browser! session "history"))))

    (fn api.merge-history-cache
      [prompt-buf active-by-prompt]
      (let [session (. active-by-prompt prompt-buf)]
        (when session
          (api.merge-history-into-session! session)
          (api.refresh-history-browser! session))))

    (fn api.insert-last-prompt
      [prompt-buf active-by-prompt prompt-insert-at-cursor!]
      (let [session (. active-by-prompt prompt-buf)
            entry (api.history-latest session)]
        (prompt-insert-at-cursor! session entry)
        (when (and session (~= entry ""))
          (set session.last-history-text entry))))

    (fn api.insert-last-token
      [prompt-buf active-by-prompt prompt-insert-at-cursor!]
      (let [session (. active-by-prompt prompt-buf)
            token (api.history-latest-token session)
            entry (api.history-latest session)]
        (prompt-insert-at-cursor! session token)
        (when (and session (~= token ""))
          (set session.last-history-text entry))))

    (fn api.insert-last-tail
      [prompt-buf active-by-prompt prompt-insert-at-cursor!]
      (let [session (. active-by-prompt prompt-buf)
            tail (api.history-latest-tail session)
            entry (api.history-latest session)]
        (prompt-insert-at-cursor! session tail)
        (when (and session (~= tail ""))
          (set session.last-history-text entry))))

    api))

M
