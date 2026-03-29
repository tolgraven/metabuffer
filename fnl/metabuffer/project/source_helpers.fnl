(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local events (require :metabuffer.events))
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))

(fn parse-prefilter-terms
  [query-lines ignorecase]
  (fn unclosed-pattern-delims?
    [token]
    (let [s (or token "")
          n (# s)]
      (var i 1)
      (var paren 0)
      (var bracket 0)
      (while (<= i n)
        (let [ch (string.sub s i i)]
          (if (= ch "%")
              (set i (+ i 2))
              (do
                (if (= ch "(")
                    (set paren (+ paren 1))
                    (= ch ")")
                    (set paren (math.max 0 (- paren 1))))
                (if (= ch "[")
                    (set bracket (+ bracket 1))
                    (= ch "]")
                    (set bracket (math.max 0 (- bracket 1))))
                (set i (+ i 1))))))
      (or (> paren 0) (> bracket 0))))

  (fn regex-token?
    [token]
    (and (= (type token) "string")
         (~= token "")
         (not (string.match token "^[%?%*%+%|%.]$"))
         (not (unclosed-pattern-delims? token))
         (not= nil (string.find token "[\\%[%]%(%)%+%*%?%|%.]"))
         (let [[ok] [(pcall vim.regex (.. "\\C" token))]]
           ok)))

  (fn prefilter-safe-token
    [tok]
    (let [raw (or tok "")
          escaped-neg? (vim.startswith raw "\\!")
          negated? (and (= (string.sub raw 1 1) "!")
                        (not escaped-neg?))
          body0 (if escaped-neg?
                    (string.sub raw 2)
                    negated?
                    (string.sub raw 2)
                    raw)
          anchor-start (and (> (# body0) 0)
                            (not (vim.startswith body0 "\\^"))
                            (= (string.sub body0 1 1) "^"))
          body1 (if anchor-start (string.sub body0 2) body0)
          anchor-end (and (> (# body1) 0)
                          (not (vim.endswith body1 "\\$"))
                          (= (string.sub body1 (# body1)) "$"))
          body2 (if anchor-end (string.sub body1 1 (- (# body1) 1)) body1)
          unescaped (-> body2
                        (string.gsub "\\\\!" "!")
                        (string.gsub "\\%^" "^")
                        (string.gsub "\\%$" "$"))]
      (if negated?
          nil
          (if (regex-token? unescaped)
              nil
              (if (~= unescaped "") unescaped nil)))))
  (let [groups []]
    (each [_ line (ipairs (or query-lines []))]
      (let [trimmed (vim.trim (or line ""))]
        (when (~= trimmed "")
          (let [toks []]
            (each [_ tok (ipairs (vim.split trimmed "%s+"))]
              (when-let [needle (prefilter-safe-token tok)]
                (table.insert toks (if ignorecase (string.lower needle) needle))))
            (when (> (# toks) 0)
              (table.insert groups toks))))))
    groups))

(fn line-matches-prefilter?
  [line spec]
  (if (or (not spec) (not spec.groups) (= (# spec.groups) 0))
      true
      (let [probe0 (or line "")
            probe (if spec.ignorecase (string.lower probe0) probe0)]
        (var all-groups true)
        (each [_ grp (ipairs spec.groups)]
          (var grp-ok true)
          (each [_ tok (ipairs grp)]
            (when (and grp-ok (not (string.find probe tok 1 true)))
              (set grp-ok false)))
          (when (and all-groups (not grp-ok))
            (set all-groups false)))
        all-groups)))

(fn reset-meta-indices!
  [meta]
  (let [all-indices []]
    (for [i 1 (# meta.buf.content)]
      (table.insert all-indices i))
    (set meta.buf.all-indices all-indices)
    (set meta.buf.indices (vim.deepcopy all-indices))))

(fn bump-content-version!
  [meta]
  (set meta.buf.content-version (+ 1 (or meta.buf.content-version 0))))

(fn file-query-matches?
  [path q ignorecase]
  (let [probe0 (or path "")
        probe (if ignorecase (string.lower probe0) probe0)
        query0 (vim.trim (or q ""))
        query (if ignorecase (string.lower query0) query0)]
    (if (= query "")
        true
        (not= nil (string.find probe query 1 true)))))

(fn path-matches-file-queries?
  [path queries ignorecase]
  (if (= (# (or queries [])) 0)
      true
      (let [path0 (or path "")
            rel (if (~= path0 "") (vim.fn.fnamemodify path0 ":.") "")
            probe (if (~= rel "")
                      (.. rel " " path0)
                      path0)
            ok0 true]
        (var ok ok0)
        (each [_ q (ipairs (or queries []))]
          (when (and ok (not (file-query-matches? probe q ignorecase)))
            (set ok false)))
        ok)))

(fn active-file-query-lines
  [session]
  (let [out []]
    (each [_ q (ipairs (or session.file-query-lines []))]
      (let [trimmed (vim.trim (or q ""))]
        (when (~= trimmed "")
          (table.insert out trimmed))))
    out))

(fn current-file-filter
  [session]
  (let [queries (active-file-query-lines session)
        active? (and session.effective-include-files (> (# queries) 0))]
    {:active? active?
     :queries queries
     :ignorecase (clj.boolean (and session.meta session.meta.ignorecase (session.meta.ignorecase)))}))

(fn file-only-mode?
  [session normal-query-active?]
  (and session.project-mode
       session.effective-include-files
       (not (normal-query-active? session))))

(fn M.new
  [opts]
  (let [{: settings : truthy? : canonical-path
         : current-buffer-path : path-under-root? : allow-project-path?
         : project-file-list : binary-file? : read-file-view-cached
         : prompt-has-active-query?} opts]

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

    (fn include-file-path?
      [path file-filter]
      (or (not (and file-filter file-filter.active?))
          (path-matches-file-queries?
            path
            (or (and file-filter file-filter.queries) [])
            (clj.boolean (and file-filter file-filter.ignorecase)))))

    (fn all-project-file-paths
      [_session include-hidden include-ignored include-deps include-binary file-filter]
      (let [root (vim.fn.getcwd)
            seen {}
            out []]
        (each [_ p (ipairs (project-file-list root include-hidden include-ignored include-deps))]
          (let [path (canonical-path p)]
            (when (and path
                       (= 1 (vim.fn.filereadable path))
                       (or include-binary (not (binary-file? path)))
                       (path-under-root? path root)
                       (include-file-path? path file-filter)
                       (not (. seen path)))
              (set (. seen path) true)
              (table.insert out path))))
        out))

    (fn results-wrap-width
      [session]
      (let [win (and session session.meta session.meta.win session.meta.win.window)]
        (when (and win (vim.api.nvim_win_is_valid win))
          (let [wrap? (clj.boolean (vim.api.nvim_get_option_value "wrap" {:win win}))]
            (when wrap?
              (let [wininfo (. (vim.fn.getwininfo win) 1)
                    textoff (or (and wininfo (. wininfo :textoff)) 0)
                    info-width (if (and session.info-win
                                        (vim.api.nvim_win_is_valid session.info-win))
                                   (vim.api.nvim_win_get_width session.info-win)
                                   0)]
                (math.max 12 (- (vim.api.nvim_win_get_width win) textoff info-width))))))))

    (fn single-source-view
      [session]
      (let [path (current-buffer-path session.source-buf)
            transforms (or session.effective-transforms session.transform-flags {})
            binary? (and path (= 1 (vim.fn.filereadable path)) (binary-file? path))
            wrap-width (results-wrap-width session)]
        (if binary?
            (if session.effective-include-binary
                (or (read-file-view-cached
                      path
                      {:include-binary true
                       :transforms transforms
                       :wrap-width wrap-width
                       :linebreak true})
                    {:lines [] :line-map []})
                {:lines [] :line-map [] :row-meta []})
            (let [raw-lines (if (and session.source-buf (vim.api.nvim_buf_is_valid session.source-buf))
                                (vim.api.nvim_buf_get_lines session.source-buf 0 -1 false)
                                (or session.single-content []))]
              (transform-mod.apply-view
                path
                raw-lines
                {:binary false
                 :path path
                 :transforms transforms
                 :wrap-width wrap-width
                 :linebreak true})))))

    (fn set-single-source-content!
      [session show-separators]
      (let [meta session.meta
            path (or (current-buffer-path session.source-buf)
                     (and (> (# (or session.single-refs [])) 0) (. (. session.single-refs 1) :path))
                     "[Current Buffer]")
            view (single-source-view session)
            content []
            refs []]
        (each [idx line (ipairs (or (. view :lines) []))]
          (let [lnum (or (. (or (. view :line-map) []) idx) idx)
                meta0 (or (. (or (. view :row-meta) []) idx) {})]
            (table.insert content (or line ""))
            (table.insert refs (vim.tbl_extend "force" {:path path :lnum lnum :line line} meta0))))
        (set meta.buf.content content)
        (set meta.buf.source-refs refs)
        (bump-content-version! meta)
        (set meta.buf.show-source-prefix false)
        (set meta.buf.show-source-separators show-separators)
        (reset-meta-indices! meta)))

    (fn normal-query-active?
      [session]
      (let [lines (or (and session.last-parsed-query session.last-parsed-query.lines) [])
            active? false]
        (var on? active?)
        (each [_ line (ipairs lines)]
          (when (and (not on?) (~= (vim.trim (or line "")) ""))
            (set on? true)))
        on?))

    (fn set-query-source-content!
      [session]
      (let [meta session.meta
            pool (or (source-mod.collect-query-source-set
                       settings
                       session.last-parsed-query
                       canonical-path)
                     {:content [] :refs []})]
        (set meta.buf.content pool.content)
        (set meta.buf.source-refs pool.refs)
        (bump-content-version! meta)
        (set meta.buf.show-source-prefix false)
        (set meta.buf.show-source-separators true)
        (reset-meta-indices! meta)))

    (fn set-file-entry-source-content!
      [session include-hidden include-ignored include-deps include-binary file-filter]
      (let [meta session.meta]
        (set meta.buf.content [])
        (set meta.buf.source-refs [])
        (each [_ path (ipairs (all-project-file-paths
                                session
                                include-hidden
                                include-ignored
                                include-deps
                                include-binary
                                file-filter))]
          (push-file-entry-into-pool! session path))
        (bump-content-version! meta)
        (set meta.buf.show-source-prefix true)
        (set meta.buf.show-source-separators true)
        (reset-meta-indices! meta)))

    (fn best-project-selection-index
      [session old-ref old-line]
      (let [meta session.meta
            refs (or meta.buf.source-refs [])
            old-ref-path (canonical-path (and old-ref old-ref.path))
            target-path (or old-ref-path (canonical-path (current-buffer-path session.source-buf)))
            target-lnum (or (and old-ref old-ref.lnum) old-line)
            fallback-idx (math.max 0 (- (meta.buf.closest-index old-line) 1))]
        (var match-idx nil)
        (when (and old-ref old-ref.path old-ref.lnum refs)
          (for [i 1 (# refs)]
            (let [r (. refs i)]
              (when (and (not match-idx)
                         r
                         (= (or (canonical-path r.path) "") (or old-ref-path ""))
                         (= (or r.lnum 0) (or old-ref.lnum 0)))
                (set match-idx i)))))
        (when (and (not match-idx) target-path refs)
          (var best-idx nil)
          (var best-dist math.huge)
          (for [i 1 (# refs)]
            (let [r (. refs i)
                  r-path (and r (canonical-path r.path))]
              (when (and r-path (= r-path target-path))
                (let [dist (math.abs (- (or r.lnum 1) (or target-lnum 1)))]
                  (when (< dist best-dist)
                    (set best-dist dist)
                    (set best-idx i))))))
          (set match-idx best-idx))
        (math.max 0
                  (math.min (if match-idx (- match-idx 1) fallback-idx)
                            (math.max 0 (- (# meta.buf.indices) 1))))))

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
                                     (line-matches-prefilter? line prefilter))
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

    (fn current-project-prefilter
      [session]
      (if (and session
               session.project-mode
               session.prefilter-mode
               session.meta
               session.meta.ignorecase)
          (let [query-lines (or (and session.last-parsed-query session.last-parsed-query.lines)
                                (and session.meta session.meta.query-lines)
                                [])
                ignorecase (clj.boolean (session.meta.ignorecase))
                groups (parse-prefilter-terms query-lines ignorecase)]
            (when (> (# groups) 0)
              {:groups groups
               :ignorecase ignorecase}))
          nil))

    (fn open-project-buffer-paths
      [session root include-hidden include-deps]
      (let [out []
            seen {}
            current (canonical-path (current-buffer-path session.source-buf))
            include-binary session.effective-include-binary]
        (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
          (when (and (vim.api.nvim_buf_is_valid buf)
                     (= (. (. vim.bo buf) :buftype) "")
                     (truthy? (. (. vim.bo buf) :buflisted)))
            (let [name (canonical-path (vim.api.nvim_buf_get_name buf))]
              (when (and name
                         (or (not current) (~= name current))
                         (not (. seen name))
                         (= 1 (vim.fn.filereadable name))
                         (or include-binary (not (binary-file? name)))
                         (path-under-root? name root))
                (let [rel (vim.fn.fnamemodify name ":.")]
                  (when (allow-project-path? rel include-hidden include-deps)
                    (set (. seen name) true)
                    (table.insert out name)))))))
        out))

    (fn estimate-lines-from-files
      [paths]
      (var bytes 0)
      (each [_ path (ipairs (or paths []))]
        (let [size (vim.fn.getfsize path)]
          (when (> size 0)
            (set bytes (+ bytes size)))))
      (math.floor (/ bytes 80)))

    (fn project-view-opts
      [session wrap-width]
      {:include-binary session.effective-include-binary
       :transforms (or session.effective-transforms {})
       :wrap-width wrap-width
       :linebreak true})

    (fn cached-project-view
      [session path wrap-width]
      (and path
           (read-file-view-cached
             path
             (project-view-opts session wrap-width))))

    (fn set-project-pool!
      [session pool]
      (let [meta session.meta]
        (set meta.buf.content pool.content)
        (set meta.buf.source-refs pool.refs)
        (bump-content-version! meta)))

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
      [session opts]
      (events.send :on-source-pool-change!
        (vim.tbl_extend "force" {:session session} (or opts {}))))

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

    {:parse-prefilter-terms parse-prefilter-terms
     :line-matches-prefilter? line-matches-prefilter?
     :reset-meta-indices! reset-meta-indices!
     :bump-content-version! bump-content-version!
     :push-file-entry-into-pool! push-file-entry-into-pool!
     :include-file-path? include-file-path?
     :all-project-file-paths all-project-file-paths
     :results-wrap-width results-wrap-width
     :single-source-view single-source-view
     :set-single-source-content! set-single-source-content!
     :normal-query-active? normal-query-active?
     :current-file-filter current-file-filter
     :file-only-mode? (fn [session] (file-only-mode? session normal-query-active?))
     :set-query-source-content! set-query-source-content!
     :set-file-entry-source-content! set-file-entry-source-content!
     :best-project-selection-index best-project-selection-index
     :push-file-into-pool! push-file-into-pool!
     :current-project-prefilter current-project-prefilter
     :open-project-buffer-paths open-project-buffer-paths
     :estimate-lines-from-files estimate-lines-from-files
     :project-view-opts project-view-opts
     :cached-project-view cached-project-view
     :set-project-pool! set-project-pool!
     :enable-full-source-syntax! enable-full-source-syntax!
     :emit-source-pool-change! emit-source-pool-change!
     :finish-project-stream! finish-project-stream!
     :maybe-finish-project-stream! maybe-finish-project-stream!}))

M
