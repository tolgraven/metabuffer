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

(fn history-entry-query
  [query-mod entry]
  (let [parsed (query-mod.parse-query-text entry)]
    (or (. parsed :query) "")))

(fn history-entry-token
  [query-mod entry]
  (let [parts (vim.split (history-entry-query query-mod entry) "%s+" {:trimempty true})]
    (if (> (# parts) 0)
        (. parts (# parts))
        "")))

(fn history-entry-tail
  [query-mod entry]
  (let [parts (vim.split (history-entry-query query-mod entry) "%s+" {:trimempty true})]
    (if (> (# parts) 1)
        (table.concat (vim.list_slice parts 2) " ")
        "")))

(fn history-entry-with-settings
  [query-mod settings session prompt]
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

(fn merge-history-into-session!
  [history-store settings session]
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

(fn history-browser-filter
  [router-util-mod session]
  (vim.trim (or (router-util-mod.prompt-text session) "")))

(fn history-browser-items
  [history-store router-util-mod session]
  (let [mode (or session.history-browser-mode "history")
        filter0 (string.lower (history-browser-filter router-util-mod session))
        out []]
    (when (= mode "saved")
      (each [_ item (ipairs (history-store.saved-items))]
        (let [tag (or (. item :tag) "")
              prompt (or (. item :prompt) "")
              hay (string.lower (.. tag " " prompt))]
          (when (or (= filter0 "")
                    (not= nil (string.find hay filter0 1 true)))
            (table.insert out {:label (.. "##" tag "  " prompt)
                               :prompt prompt
                               :tag tag})))))
    (when (not= mode "saved")
      (let [h (or session.history-cache (history-store.list))]
        (for [i (# h) 1 -1]
          (let [entry (or (. h i) "")
                hay (string.lower entry)]
            (when (or (= filter0 "")
                      (not= nil (string.find hay filter0 1 true)))
              (table.insert out {:label entry :prompt entry}))))))
    out))

(fn history-latest
  [history-store session]
  (let [h (or (and session session.history-cache) (history-store.list))
        n (# h)]
    (if (> n 0) (. h n) "")))

(fn history-or-move!
  [history-store history-browser-window router-util-mod query-mod prompt-buf delta active-by-prompt move-selection-fn]
  (let [session (. active-by-prompt prompt-buf)]
    (when session
      (if session.history-browser-active
          (history-browser-window.move! session delta)
          (let [txt (router-util-mod.prompt-text session)
                can-history (or (= txt "")
                                (= txt session.initial-prompt-text)
                                (= txt session.last-history-text)
                                (= txt (history-entry-query query-mod session.last-history-text)))]
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
                            (set session.last-history-text entry)
                            (router-util-mod.set-prompt-text! session entry))))))
                (move-selection-fn prompt-buf delta)))))))

(fn insert-history-fragment!
  [history-store query-mod prompt-buf active-by-prompt prompt-insert-at-cursor! mode]
  (let [session (. active-by-prompt prompt-buf)
        entry (history-latest history-store session)
        text (if (= mode :prompt)
                 entry
                 (if (= mode :token)
                     (history-entry-token query-mod entry)
                     (history-entry-tail query-mod entry)))]
    (prompt-insert-at-cursor! session text)
    (when (and session (~= text ""))
      (set session.last-history-text entry))))

(fn M.new
  [opts]
  (let [history-store (. opts :history-store)
        router-util-mod (. opts :router-util-mod)
        query-mod (. opts :query-mod)
        history-browser-window (. opts :history-browser-window)
        settings (. opts :settings)]
    {:history-entry-query (fn [entry]
                            (history-entry-query query-mod entry))
     :history-entry-token (fn [entry]
                            (history-entry-token query-mod entry))
     :history-entry-tail (fn [entry]
                           (history-entry-tail query-mod entry))
     :history-entry-with-settings (fn [session prompt]
                                    (history-entry-with-settings query-mod settings session prompt))
     :push-history-entry! (fn [session text]
                            (history-store.push! (history-entry-with-settings query-mod settings session text)
                                                 settings.history-max))
     :merge-history-into-session! (fn [session]
                                    (merge-history-into-session! history-store settings session))
     :save-current-prompt-tag! (fn [_session tag prompt]
                                 (when (and (= (type tag) "string")
                                            (~= (vim.trim tag) "")
                                            (= (type prompt) "string")
                                            (~= (vim.trim prompt) ""))
                                   (history-store.save-tag! tag prompt)))
     :restore-saved-prompt-tag! (fn [session tag]
                                  (when (and session
                                             (= (type tag) "string")
                                             (~= (vim.trim tag) ""))
                                    (when-let [saved (history-store.saved-entry tag)]
                                      (router-util-mod.set-prompt-text! session saved)
                                      true)))
     :history-browser-filter (fn [session]
                               (history-browser-filter router-util-mod session))
     :history-browser-items (fn [session]
                              (history-browser-items history-store router-util-mod session))
     :refresh-history-browser! (fn [session]
                                 (when (and session history-browser-window session.history-browser-active)
                                   (set session.history-browser-filter (history-browser-filter router-util-mod session))
                                   (history-browser-window.refresh! session
                                                                    (history-browser-items history-store router-util-mod session))))
     :close-history-browser! (fn [session]
                               (when history-browser-window
                                 (history-browser-window.close! session)))
     :open-history-browser! (fn [session mode]
                              (when history-browser-window
                                (history-browser-window.open! session (or mode "history"))
                                (set session.history-browser-filter (history-browser-filter router-util-mod session))
                                (history-browser-window.refresh! session
                                                                 (history-browser-items history-store router-util-mod session))))
     :apply-history-browser-selection! (fn [session]
                                         (when (and history-browser-window session.history-browser-active)
                                           (when-let [selected (history-browser-window.selected! session)]
                                             (when-let [prompt (. selected :prompt)]
                                               (router-util-mod.set-prompt-text! session prompt)))
                                           (history-browser-window.close! session)))
     :history-latest (fn [session]
                       (history-latest history-store session))
     :history-latest-token (fn [session]
                             (history-entry-token query-mod (history-latest history-store session)))
     :history-latest-tail (fn [session]
                            (history-entry-tail query-mod (history-latest history-store session)))
     :last-prompt-entry (fn [prompt-buf active-by-prompt]
                          (history-latest history-store (. active-by-prompt prompt-buf)))
     :last-prompt-token (fn [prompt-buf active-by-prompt]
                          (history-entry-token query-mod (history-latest history-store (. active-by-prompt prompt-buf))))
     :last-prompt-tail (fn [prompt-buf active-by-prompt]
                         (history-entry-tail query-mod (history-latest history-store (. active-by-prompt prompt-buf))))
     :saved-prompt-entry (fn [tag]
                           (history-store.saved-entry tag))
     :history-or-move (fn [prompt-buf delta active-by-prompt move-selection-fn]
                        (history-or-move! history-store history-browser-window router-util-mod query-mod prompt-buf delta active-by-prompt move-selection-fn))
     :open-history-searchback (fn [prompt-buf active-by-prompt]
                                (let [session (. active-by-prompt prompt-buf)]
                                  (when session
                                    (when-not session.history-cache
                                      (set session.history-cache (vim.deepcopy (history-store.list))))
                                    (when history-browser-window
                                      (history-browser-window.open! session "history")
                                      (set session.history-browser-filter (history-browser-filter router-util-mod session))
                                      (history-browser-window.refresh! session
                                                                       (history-browser-items history-store router-util-mod session))))))
     :merge-history-cache (fn [prompt-buf active-by-prompt]
                            (let [session (. active-by-prompt prompt-buf)]
                              (when session
                                (merge-history-into-session! history-store settings session)
                                (when (and history-browser-window session.history-browser-active)
                                  (set session.history-browser-filter (history-browser-filter router-util-mod session))
                                  (history-browser-window.refresh! session
                                                                   (history-browser-items history-store router-util-mod session))))))
     :insert-last-prompt (fn [prompt-buf active-by-prompt prompt-insert-at-cursor!]
                           (insert-history-fragment! history-store query-mod prompt-buf active-by-prompt prompt-insert-at-cursor! :prompt))
     :insert-last-token (fn [prompt-buf active-by-prompt prompt-insert-at-cursor!]
                          (insert-history-fragment! history-store query-mod prompt-buf active-by-prompt prompt-insert-at-cursor! :token))
     :insert-last-tail (fn [prompt-buf active-by-prompt prompt-insert-at-cursor!]
                         (insert-history-fragment! history-store query-mod prompt-buf active-by-prompt prompt-insert-at-cursor! :tail))}))

M
