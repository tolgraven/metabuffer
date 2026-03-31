(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local events (require :metabuffer.events))

(fn M.new
  [opts]
  "Build project source-pool mutation and completion helpers."
  (let [{: settings : prompt-has-active-query?} (or opts {})]
    (fn push-file-entry-into-pool!
      [session path]
      (let [meta session.meta
            content meta.buf.content
            refs meta.buf.source-refs
            rel (vim.fn.fnamemodify path ":.")
            line ""]
        (table.insert content line)
        (table.insert refs {:path path
                            :lnum 1
                            :line (if (and (= (type rel) "string") (~= rel ""))
                                      rel
                                      path)
                            :kind "file-entry"
                            :open-lnum 1
                            :preview-lnum 1})))

    (fn push-file-into-pool!
      [session path view prefilter]
      (let [lines (and view (. view :lines))
            line-map (or (and view (. view :line-map)) [])
            row-meta (or (and view (. view :row-meta)) [])]
        (if (or (not lines) (= (type lines) "nil"))
            0
            (let [meta session.meta
                  content meta.buf.content
                  refs meta.buf.source-refs
                  start-n (# content)
                  take (math.max 0 (- settings.project-max-total-lines start-n))
                  has-prefilter (and prefilter prefilter.groups (> (# prefilter.groups) 0))]
              (if (<= take 0)
                  0
                  (do
                    (var added 0)
                    (if has-prefilter
                        (each [lnum line (ipairs lines)]
                          (when (and (< added take)
                                     ((. opts :line-matches-prefilter?) line prefilter))
                            (table.insert content line)
                            (table.insert refs (vim.tbl_extend "force"
                                                               {:path path :lnum (or (. line-map lnum) lnum) :line line}
                                                               (or (. row-meta lnum) {})))
                            (set added (+ added 1))))
                        (each [lnum line (ipairs lines)]
                          (when (< added take)
                            (table.insert content line)
                            (table.insert refs (vim.tbl_extend "force"
                                                               {:path path :lnum (or (. line-map lnum) lnum) :line line}
                                                               (or (. row-meta lnum) {})))
                            (set added (+ added 1)))))
                    (when (> added 0)
                      (for [i (+ start-n 1) (# content)]
                        (table.insert meta.buf.all-indices i)))
                    added))))))

    (fn set-project-pool!
      [session pool]
      (let [meta session.meta]
        (set meta.buf.content pool.content)
        (set meta.buf.source-refs pool.refs)
        ((. opts :bump-content-version!) meta)))

    (fn enable-full-source-syntax!
      [session]
      (when (and session.meta
                 session.meta.buf
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (set session.meta.buf.visible-source-syntax-only false)
        (events.send :on-source-syntax-refresh!
          {:session session
           :immediate? true})))

    (fn emit-source-pool-change!
      [session extra]
      (events.send :on-source-pool-change!
        (vim.tbl_extend "force" {:session session} (or extra {}))))

    (fn finish-project-stream!
      [session sent-complete?]
      (set session.lazy-stream-done true)
      (enable-full-source-syntax! session)
      (when-not sent-complete?
        (emit-source-pool-change!
          session
          {:phase :complete
           :phase-only? true
           :force? true
           :refresh-lines true})))

    (fn maybe-finish-project-stream!
      [session]
      (when (and session.lazy-stream-done
                 session.meta
                 session.meta.buf
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (let [has-query? (prompt-has-active-query? session)
              sent-complete? false]
          (var sent-complete sent-complete?)
          (when-not has-query?
            (emit-source-pool-change!
              session
              {:phase :complete
               :force? true
               :refresh-lines true
               :restore-view? true})
            (set sent-complete true))
          (finish-project-stream! session sent-complete))))

    {:push-file-entry-into-pool! push-file-entry-into-pool!
     :push-file-into-pool! push-file-into-pool!
     :set-project-pool! set-project-pool!
     :enable-full-source-syntax! enable-full-source-syntax!
     :emit-source-pool-change! emit-source-pool-change!
     :finish-project-stream! finish-project-stream!
     :maybe-finish-project-stream! maybe-finish-project-stream!}))

M
