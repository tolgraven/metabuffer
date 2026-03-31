(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local router_util_mod (require :metabuffer.router.util))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))
(local M {})

(fn choose-current-when-nil
  [value current]
  (if-some [v value] v current))

(fn prompt-delay-ms
  [settings query-mod session]
  (router_prompt_mod.prompt-update-delay-ms
    settings
    query-mod
    router_util_mod.prompt-lines
    session))

(fn schedule-update!
  [prompt-scheduler-ctx session delay]
  (router_prompt_mod.schedule-prompt-update!
    prompt-scheduler-ctx
    session
    delay))

(fn force-within-idle-window?
  [settings session now]
  (and (> (math.max 0 (or settings.prompt-update-idle-ms 0)) 0)
       (< (- now (or session.prompt-last-change-ms 0))
          (math.max 0 (or settings.prompt-update-idle-ms 0)))))

(fn queue-update-after-edit!
  [settings prompt-scheduler-ctx session force now delay]
  (when-not (and force session.prompt-update-pending)
    (if (and force (force-within-idle-window? settings session now))
        (schedule-update!
          prompt-scheduler-ctx
          session
          (math.max delay settings.prompt-update-idle-ms))
        (schedule-update! prompt-scheduler-ctx session delay))))

(fn invalidate-filter-cache!
  [session]
  (when (and session session.meta)
    (set session.meta._prev_text "")
    (set session.meta._filter-cache {})
    (set session.meta._filter-cache-line-count (# session.meta.buf.content))))

(fn invalidate-info-refresh-state!
  [session]
  "Clear stale info-window render/loading state before a real query refresh."
  (when session
    (set session.info-render-sig nil)
    (set session.info-line-meta-range-key nil)
    (set session.info-project-finish-refresh-pending? false)
    (set session.info-highlight-fill-pending? false)
    (set session.info-showing-project-loading? nil)
    (set session.info-project-loading-active? nil)
    (set session.info-last-selected-index nil)))

(fn resolve-parsed-query
  [query-mod session parsed]
  (query-mod.apply-default-source
    parsed
    (and session (query-mod.truthy? session.default-include-lgrep))))

(fn source-flags-changed?
  [session parsed]
  (let [next-hidden (choose-current-when-nil (. parsed :include-hidden) session.include-hidden)
        next-ignored (choose-current-when-nil (. parsed :include-ignored) session.include-ignored)
        next-deps (choose-current-when-nil (. parsed :include-deps) session.include-deps)
        next-binary (choose-current-when-nil (. parsed :include-binary) session.include-binary)
        next-files (choose-current-when-nil (. parsed :include-files) session.include-files)
        next-transforms (transform-mod.enabled-map parsed session nil)
        next-source (source-mod.query-source-signature parsed)
        cur-source (source-mod.query-source-signature (or session.last-parsed-query {}))]
    (or (~= next-hidden session.effective-include-hidden)
        (~= next-ignored session.effective-include-ignored)
        (~= next-deps session.effective-include-deps)
        (~= next-binary session.effective-include-binary)
        (~= next-files session.effective-include-files)
        (~= (transform-mod.signature next-transforms)
            (transform-mod.signature (or session.effective-transforms {})))
        (~= next-source cur-source))))

(fn render-flags-changed?
  [session parsed]
  (let [next-prefilter (choose-current-when-nil (. parsed :prefilter) session.prefilter-mode)
        next-lazy (choose-current-when-nil (. parsed :lazy) session.lazy-mode)
        next-expansion (choose-current-when-nil (. parsed :expansion) session.expansion-mode)]
    (or (~= next-prefilter session.prefilter-mode)
        (~= next-lazy session.lazy-mode)
        (~= next-expansion session.expansion-mode))))

(fn file-lines-changed?
  [session parsed]
  "Return true when the file-filter tokens differ from the previous update."
  (let [prev (or session.file-query-lines [])
        next (or (and parsed (. parsed :file-lines)) [])
        n (# next)]
    (if (~= n (# prev))
        true
        (do
          (var diff false)
          (for [i 1 n]
            (when (and (not diff) (~= (. prev i) (. next i)))
              (set diff true)))
          diff))))

(fn dispatch-directive-changes!
  [session parsed]
  "Compare parsed directives against session.last-parsed-query and fire
   :on-directive! for each changed key."
  (let [directive-mod (require :metabuffer.query.directive)
        prev (or session.last-parsed-query {})
        seen {}]
    (each [_ spec (ipairs (directive-mod.all-specs))]
      (let [key (. spec :token-key)]
        (when (and key (not (. seen key)))
          (set (. seen key) true)
          (let [old-val (. prev key)
                new-val (. parsed key)]
            (when (~= old-val new-val)
              (events.send :on-directive!
                {:session session
                 :key key
                 :value new-val
                 :change {:old old-val
                          :new new-val
                          :activated? (and (= old-val nil) (~= new-val nil))
                          :deactivated? (and (~= old-val nil) (= new-val nil))
                          :kind (or (. spec :kind) "")
                          :provider-type (or (. spec :provider-type) "")}}))))))))

(fn retry-textlock-update!
  [session]
  (vim.defer_fn
    (fn []
      (when (and session.meta
                 (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
        (pcall session.meta.on-update 0)
        (events.send :on-query-update!
          {:session session
           :query (or session.prompt-last-applied-text "")
           :refresh-lines true
           :refresh-signs? true
           :capture-sign-baseline? true})))
    1))

(fn run-meta-update!
  [session]
  (let [[ok err] [(pcall session.meta.on-update 0)]]
    (if ok
        (events.send :on-query-update!
          {:session session
           :query (or session.prompt-last-applied-text "")
           :refresh-lines true
           :refresh-signs? true
           :capture-sign-baseline? true})
        (when (string.find (tostring err) "E565")
          (retry-textlock-update! session)))))

(fn consume-visible-control-token?
  [query-mod tok]
  (let [parsed (query-mod.parse-query-lines [(or tok "")])]
    (and (or (~= (. parsed :include-hidden) nil)
             (~= (. parsed :include-ignored) nil)
             (~= (. parsed :include-deps) nil)
             (~= (. parsed :include-binary) nil)
             (~= (. parsed :prefilter) nil)
             (~= (. parsed :lazy) nil)
             (. parsed :history)
             (. parsed :saved-browser)
             (and (= (type (. parsed :save-tag)) "string")
                  (~= (vim.trim (. parsed :save-tag)) ""))
             (and (= (type (. parsed :saved-tag)) "string")
                  (~= (vim.trim (. parsed :saved-tag)) "")))
         (= (. parsed :include-files) nil)
         (= (. parsed :include-binary) nil)
         (= (transform-mod.signature (transform-mod.enabled-map parsed nil nil)) ""))))

(fn consume-visible-controls-lines
  [query-mod raw-lines]
  (let [out []]
    (each [_ line (ipairs (or raw-lines []))]
      (let [parts (vim.split (or line "") "%s+" {:trimempty true})
            kept []]
        (each [_ tok (ipairs parts)]
          (when-not (consume-visible-control-token? query-mod tok)
            (table.insert kept tok)))
        (table.insert out (table.concat kept " "))))
    out))

(fn handle-history-directives!
  [deps session parsed effective-text]
  (let [history (. deps :history)
        merge-history-into-session! (. history :merge-into-session!)
        save-current-prompt-tag! (. history :save-current-prompt-tag!)
        restore-saved-prompt-tag! (. history :restore-saved-prompt-tag!)
        open-saved-browser! (. history :open-saved-browser!)]
    (when (and (. parsed :history) merge-history-into-session!)
      (merge-history-into-session! session))
    (when (and (= (type (. parsed :save-tag)) "string")
               (~= (vim.trim (. parsed :save-tag)) "")
               save-current-prompt-tag!)
      (save-current-prompt-tag! session (. parsed :save-tag) effective-text))
    (when (and (= (type (. parsed :saved-tag)) "string")
               (~= (vim.trim (. parsed :saved-tag)) "")
               restore-saved-prompt-tag!)
      (restore-saved-prompt-tag! session (. parsed :saved-tag)))
    (when (and (. parsed :saved-browser)
               open-saved-browser!)
      (open-saved-browser! session))))

(fn apply-query-state!
  [session parsed state]
  (let [{: effective-text : next-hidden : next-ignored : next-deps
         : next-binary : next-files : next-transforms : next-prefilter
         : next-lazy : next-expansion}
        state]
    (set session.effective-include-hidden next-hidden)
    (set session.effective-include-ignored next-ignored)
    (set session.effective-include-deps next-deps)
    (set session.effective-include-binary next-binary)
    (set session.effective-include-files next-files)
    (set session.include-hidden next-hidden)
    (set session.include-ignored next-ignored)
    (set session.include-deps next-deps)
    (set session.include-binary next-binary)
    (set session.include-files next-files)
    (transform-mod.apply-flags! session next-transforms)
    (set session.prefilter-mode next-prefilter)
    (set session.lazy-mode next-lazy)
    (set session.expansion-mode next-expansion)
    (set session.last-parsed-query parsed)
    (set session.file-query-lines (or (. parsed :file-lines) []))
    (set session.last-prompt-text effective-text)
    (set session.prompt-last-applied-text effective-text)
    (set session.prompt-last-event-text effective-text)
    (set session.meta.file-query-lines (or (. parsed :file-lines) []))
    (set session.meta.include-binary next-binary)
    (set session.meta.include-files next-files)
    (transform-mod.apply-flags! session.meta next-transforms)
    (set session.meta.debug_out "")))

(fn maybe-rewrite-visible-controls!
  [session query-mod raw-lines]
  (let [consume-visible-controls? false]
    (when consume-visible-controls?
      (let [visible-lines (consume-visible-controls-lines query-mod raw-lines)
            visible-text (table.concat visible-lines "\n")
            raw-text (table.concat raw-lines "\n")]
        (when (~= visible-text raw-text)
          (set session._rewriting-visible-controls true)
          (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false visible-lines)
          (set session._rewriting-visible-controls false))))))

(fn maybe-rebuild-source!
  [session parsed project-source state]
  (let [schedule-source-set-rebuild! (. project-source :schedule-source-set-rebuild!)
        apply-source-set! (. project-source :apply-source-set!)
        prev-source (. state :prev-source)
        next-source (. state :next-source)
        source-changed? (. state :source-changed?)]
    (when (and (or session.project-mode
                   session.active-source-key
                   (source-mod.query-source-active? parsed))
               source-changed?)
      (when (~= next-source prev-source)
        (events.send :on-source-switch!
          {:session session
           :old-source prev-source
           :new-source next-source}))
      (if schedule-source-set-rebuild!
          (schedule-source-set-rebuild! session 0)
          (when apply-source-set!
            (apply-source-set! session))))))

(fn finish-query-apply!
  [session effective-lines effective-text state]
  (session.meta.set-query-lines effective-lines)
  (if (and session.project-mode
           (. state :source-changed?)
           (not (. state :text-changed?)))
      (events.send :on-query-update!
        {:session session
         :query effective-text
         :refresh-lines true
         :refresh-signs? true
         :capture-sign-baseline? true})
      (run-meta-update! session)))

(fn prompt-edit-state
  [settings query-mod session parsed force]
  (let [effective-text (table.concat (or (. parsed :lines) []) "\n")
        source-changed? (source-flags-changed? session parsed)
        render-changed? (render-flags-changed? session parsed)
        no-flag-change? (and (not source-changed?)
                             (not render-changed?))
        pure-flag-edit? (and (~= effective-text (or session.prompt-last-event-text ""))
                             (= effective-text (or session.prompt-last-applied-text ""))
                             (or source-changed? render-changed?))
        noop? (and (not force)
                   no-flag-change?
                   (not (file-lines-changed? session parsed))
                   (= effective-text (or session.prompt-last-applied-text ""))
                   (= effective-text (or session.prompt-last-event-text "")))]
    {:effective-text effective-text
     :pure-flag-edit? pure-flag-edit?
     :noop? noop?
     :now (router_prompt_mod.now-ms)
     :delay (prompt-delay-ms settings query-mod session)}))

(fn mark-prompt-edit!
  [session force event-tick state]
  (let [now (. state :now)
        delay (. state :delay)
        effective-text (. state :effective-text)]
    (set session.prompt-last-event-text effective-text)
    (when (and (not force) event-tick)
      (set session.prompt-last-event-tick event-tick))
    (set session.prompt-update-dirty true)
    (when-not force
      (set session.prompt-last-change-ms now)
      (set session.prompt-force-block-until (+ now (math.max 0 delay))))
    (when-not force
      (set session.prompt-change-seq (+ 1 (or session.prompt-change-seq 0))))))

(fn maybe-schedule-bootstrap!
  [settings project-source session]
  (when (and session.project-mode
             (not session.project-bootstrapped))
    (project-source.schedule-project-bootstrap! session settings.project-bootstrap-delay-ms)))

(fn run-prompt-edit!
  [deps session force state]
  (let [router (. deps :router)
        project (. deps :project)
        deps-state (. deps :state)
        settings router
        project-source (. project :source)
        prompt-scheduler-ctx (. deps-state :prompt-scheduler-ctx)
        now (. state :now)
        delay (. state :delay)]
    (maybe-schedule-bootstrap! settings project-source session)
    (if (. state :pure-flag-edit?)
        (do
          (set session.last-prompt-text (. state :effective-text))
          (set session.prompt-last-change-ms now)
          (set session.prompt-update-dirty false)
          (router_prompt_mod.cancel-prompt-update! session)
          (M.apply-prompt-lines! deps session))
        (queue-update-after-edit! settings prompt-scheduler-ctx session force now delay))))

(fn M.apply-prompt-lines!
  [deps session]
  (let [{: mods : project} deps
        query-mod (. mods :query)
        project-source (. project :source)]
    (when (and session
               (not session.closing)
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (not session._rewriting-visible-controls))
      (let [raw-lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
        (let [parsed (resolve-parsed-query
                       query-mod
                       session
                       (query-mod.parse-query-lines raw-lines))
              lines (. parsed :lines)
              effective-lines lines
              effective-text (table.concat effective-lines "\n")
              next-hidden (choose-current-when-nil (. parsed :include-hidden) session.include-hidden)
              next-ignored (choose-current-when-nil (. parsed :include-ignored) session.include-ignored)
              next-deps (choose-current-when-nil (. parsed :include-deps) session.include-deps)
              next-binary (choose-current-when-nil (. parsed :include-binary) session.include-binary)
              next-files (choose-current-when-nil (. parsed :include-files) session.include-files)
              next-transforms (transform-mod.enabled-map parsed session nil)
              next-prefilter (choose-current-when-nil (. parsed :prefilter) session.prefilter-mode)
              next-lazy (choose-current-when-nil (. parsed :lazy) session.lazy-mode)
              next-expansion (choose-current-when-nil (. parsed :expansion) session.expansion-mode)
              prev-source (source-mod.query-source-signature (or session.last-parsed-query {}))
              next-source (source-mod.query-source-signature parsed)
              prev-effective-text (or session.prompt-last-applied-text "")
              text-changed? (~= effective-text prev-effective-text)
              source-changed? (source-flags-changed? session parsed)
              render-changed? (render-flags-changed? session parsed)
              changed (or source-changed? render-changed?)
              state {:effective-text effective-text
                     :next-hidden next-hidden
                     :next-ignored next-ignored
                     :next-deps next-deps
                     :next-binary next-binary
                     :next-files next-files
                     :next-transforms next-transforms
                     :next-prefilter next-prefilter
                     :next-lazy next-lazy
                     :next-expansion next-expansion
                     :prev-source prev-source
                     :next-source next-source
                     :text-changed? text-changed?
                     :source-changed? source-changed?}]
          (handle-history-directives! deps session parsed effective-text)
          (dispatch-directive-changes! session parsed)
          (apply-query-state! session parsed state)
          (maybe-rewrite-visible-controls! session query-mod raw-lines)
          (when (or changed text-changed? (file-lines-changed? session parsed))
            (invalidate-filter-cache! session))
          (when (or text-changed? (file-lines-changed? session))
            (invalidate-info-refresh-state! session))
          (when (and session.meta session.meta.buf (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
            (pcall vim.api.nvim_buf_set_var session.meta.buf.buffer "meta_manual_edit_active" false))
          (maybe-rebuild-source! session parsed project-source state)
          (finish-query-apply! session effective-lines effective-text state))))))

(fn M.on-prompt-changed!
  [deps prompt-buf force event-tick]
  "Entry point for prompt edits; keeps typing fast by deferring matcher work."
  (let [{: router : mods} deps
        active-by-prompt (. router :active-by-prompt)
        query-mod (. mods :query)
        settings router
        session (. active-by-prompt prompt-buf)]
    (when (and session (not session.closing))
      (let [lines (router_util_mod.prompt-lines session)
            parsed (resolve-parsed-query query-mod session (query-mod.parse-query-lines lines))
            edit-state (prompt-edit-state settings query-mod session parsed force)]
        (when-not (. edit-state :noop?)
          (mark-prompt-edit! session force event-tick edit-state)
          (run-prompt-edit! deps session force edit-state))))))

M
