(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local source-mod (require :metabuffer.source))
(local transform-mod (require :metabuffer.transform))
(local events (require :metabuffer.events))
(local M {})

(fn M.new
  [opts]
  "Build writeback and live-edit projection helpers."
  (let [_ (or opts {})]
    (fn diff-hunks
      [old-lines new-lines]
      (let [old-text (table.concat (or old-lines []) "\n")
            new-text (table.concat (or new-lines []) "\n")
            [ok out] [(pcall vim.diff old-text new-text {:result_type "indices" :algorithm "histogram"})]]
        (if (and ok (= (type out) "table")) out [])))

    (fn hunk-indices
      [h]
      [(or (. h 1) 1) (or (. h 2) 0) (or (. h 3) 1) (or (. h 4) 0)])

    (fn slice-lines
      [lines start count]
      (let [out []]
        (for [i start (+ start count -1)]
          (when (and (>= i 1) (<= i (# lines)))
            (table.insert out (. lines i))))
        out))

    (fn clone-row-with-text
      [row text]
      (let [r (vim.deepcopy (or row {}))]
        (set (. r :text) (or text ""))
        (set (. r :line) (or text ""))
        r))

    (fn consecutive-same-source?
      [prev-row next-row]
      (and prev-row
           next-row
           (= (type (. prev-row :path)) "string")
           (= (type (. next-row :path)) "string")
           (~= (. prev-row :path) "")
           (~= (. next-row :path) "")
           (= (type (. prev-row :lnum)) "number")
           (= (type (. next-row :lnum)) "number")
           (= (. prev-row :path) (. next-row :path))
           (= (+ (. prev-row :lnum) 1) (. next-row :lnum))))

    (fn inserted-row
      [session prev-row next-row text rel-index]
      (let [base (or prev-row next-row {})
            out (vim.deepcopy base)
            prev-lnum (or (and prev-row (. prev-row :lnum)) (. base :lnum) 1)
            next-lnum (or (and next-row (. next-row :lnum)) (. base :lnum) (+ prev-lnum 1))
            pending (or session.pending-structural-edit {})
            pending-side (. pending :side)
            pending-path (. pending :path)
            pending-lnum (. pending :lnum)
            lnum (if (consecutive-same-source? prev-row next-row)
                     (+ prev-lnum rel-index)
                     (if (and (= pending-side "after")
                              prev-row
                              (= pending-path (. prev-row :path))
                              (= pending-lnum (. prev-row :lnum)))
                         (+ pending-lnum rel-index)
                         (if (and (= pending-side "before")
                                  next-row
                                  (= pending-path (. next-row :path))
                                  (= pending-lnum (. next-row :lnum)))
                             (+ pending-lnum rel-index -1)
                             (if prev-row
                                 (+ prev-lnum rel-index)
                                 (math.max 1 (- next-lnum 1))))))]
        (set (. out :lnum) (math.max 1 (or lnum 1)))
        (set (. out :text) (or text ""))
        (set (. out :line) (or text ""))
        (if (consecutive-same-source? prev-row next-row)
            (do
              (set (. out :insert-path) (. prev-row :path))
              (set (. out :insert-lnum) (. prev-row :lnum))
              (set (. out :insert-side) "after"))
            (do
              (when (and (= pending-side "after")
                         prev-row
                         (= (type (. prev-row :path)) "string")
                         (~= (. prev-row :path) "")
                         (= (type (. prev-row :lnum)) "number")
                         (= pending-path (. prev-row :path))
                         (= pending-lnum (. prev-row :lnum)))
                (set (. out :insert-path) (. prev-row :path))
                (set (. out :insert-lnum) (. prev-row :lnum))
                (set (. out :insert-side) "after"))
              (when (and (= pending-side "before")
                         next-row
                         (= (type (. next-row :path)) "string")
                         (~= (. next-row :path) "")
                         (= (type (. next-row :lnum)) "number")
                         (= pending-path (. next-row :path))
                         (= pending-lnum (. next-row :lnum)))
                (set (. out :insert-path) (. next-row :path))
                (set (. out :insert-lnum) (. next-row :lnum))
                (set (. out :insert-side) "before"))))
        out))

    (fn projected-rows-from-edits
      [session baseline-rows baseline-lines current-lines]
      (let [hunks (diff-hunks baseline-lines current-lines)
            out []
            idx {:old 1 :new 1}]
        (each [_ h (ipairs hunks)]
          (let [[a-start a-count b-start b-count] (hunk-indices h)
                common (math.min a-count b-count)]
            (while (< (. idx :old) a-start)
              (let [txt (or (. current-lines (. idx :new)) "")]
                (table.insert out (clone-row-with-text (. baseline-rows (. idx :old)) txt))
                (set (. idx :old) (+ (. idx :old) 1))
                (set (. idx :new) (+ (. idx :new) 1))))
            (for [k 1 common]
              (let [txt (or (. current-lines (+ b-start k -1)) "")]
                (table.insert out (clone-row-with-text (. baseline-rows (+ a-start k -1)) txt))))
            (when (> b-count a-count)
              (let [extra (- b-count common)
                    prev-row (if (> (+ a-start common -1) 0)
                                 (. baseline-rows (+ a-start common -1))
                                 nil)
                    next-row (. baseline-rows (+ a-start common))]
                (for [k 1 extra]
                  (let [txt (or (. current-lines (+ b-start common k -1)) "")]
                    (table.insert out (inserted-row session prev-row next-row txt k))))))
            (set (. idx :old) (+ a-start a-count))
            (set (. idx :new) (+ b-start b-count))))
        (while (<= (. idx :old) (# baseline-rows))
          (let [txt (or (. current-lines (. idx :new)) "")]
            (table.insert out (clone-row-with-text (. baseline-rows (. idx :old)) txt))
            (set (. idx :old) (+ (. idx :old) 1))
            (set (. idx :new) (+ (. idx :new) 1))))
        out))

    (fn apply-live-edits-to-meta!
      [session current-lines]
      (let [meta session.meta
            baseline-lines (or session.edit-baseline-lines [])
            baseline-rows (or session.edit-baseline-rows [])
            rows (projected-rows-from-edits session baseline-rows baseline-lines current-lines)
            refs []
            content []
            idxs []]
        (set session.live-edit-rows rows)
        (for [i 1 (# rows)]
          (let [row (or (. rows i) {})]
            (set (. refs i) {:kind (or (. row :kind) "")
                             :path (or (. row :path) "")
                             :lnum (or (. row :lnum) 1)
                             :open-lnum (or (. row :open-lnum) (. row :lnum) 1)
                             :line (or (. row :text) (. row :line) "")})
            (set (. content i) (or (. row :text) (. row :line) ""))
            (set (. idxs i) i)))
        (set meta.buf.source-refs refs)
        (set meta.buf.content content)
        (set meta.buf.indices idxs)
        (let [max (math.max 1 (# idxs))]
          (set meta.selected_index
               (math.max 0 (math.min (or meta.selected_index 0) (- max 1)))))))

    (fn valid-row?
      [row]
      (and row
           (= (type (. row :path)) "string")
           (~= (. row :path) "")
           (= (type (. row :lnum)) "number")
           (> (. row :lnum) 0)))

    (fn special-projected-row?
      [row]
      (and row
           (. row :source-group-id)
           (or (> (# (or (. row :transform-chain) [])) 0)
               (= (or (. row :source-group-kind) "") "file"))))

    (fn append-op!
      [ops path op]
      (let [per-file (or (. ops path) [])]
        (table.insert per-file op)
        (set (. ops path) per-file)))

    (fn append-group-op!
      [ops row current-rows processed]
      (let [group-id (. row :source-group-id)
            path (. row :path)
            key (.. path "|" (tostring group-id))
            group-lines []]
        (if (. (or processed {}) key)
            nil
            (do
              (set (. processed key) true)
              (each [_ r (ipairs (or current-rows []))]
                (when (and (= (. r :path) path)
                           (= (. r :source-group-id) group-id))
                  (table.insert group-lines (or (. r :text) (. r :line) ""))))
              (let [reversed (transform-mod.reverse-group row group-lines {:path path :lnum (. row :lnum)})]
                (if (. reversed :error)
                    {:error (. reversed :error)}
                    (do
                      (if (= (. reversed :kind) :rewrite-bytes)
                          (append-op! ops path {:kind :rewrite-bytes
                                                :bytes (. reversed :bytes)
                                                :ref-kind (or (. row :kind) "")})
                          (append-op! ops path {:kind :replace
                                                :lnum (. row :lnum)
                                                :text (. reversed :text)
                                                :old-text (or (. row :source-text) "")
                                                :ref-kind (or (. row :kind) "")}))
                      nil)))))))

    (fn structural-op-from-current-rows
      [current-rows start count]
      (let [rows (slice-lines current-rows start count)
            first-row (. rows 1)]
        (if (and first-row
                 (. first-row :insert-path)
                 (. first-row :insert-lnum)
                 (. first-row :insert-side))
            (let [path (. first-row :insert-path)
                  lnum (. first-row :insert-lnum)
                  side (. first-row :insert-side)
                  ref-kind (or (. first-row :kind) "")
                  lines []
                  state {:consistent? true}]
              (each [_ row (ipairs rows)]
                (when (or (~= (. row :insert-path) path)
                          (~= (. row :insert-lnum) lnum)
                          (~= (. row :insert-side) side))
                  (set (. state :consistent?) false))
                (table.insert lines (or (. row :text) (. row :line) "")))
              (when (. state :consistent?)
                {:path path :lnum lnum :side side :lines lines :ref-kind ref-kind}))
            nil)))

    (fn pending-structural-op
      [session start count current-lines fallback-kind]
      (let [pending (or session.pending-structural-edit {})
            path (. pending :path)
            lnum (. pending :lnum)
            side (. pending :side)
            ref-kind (or (. pending :kind) fallback-kind "")]
        (when (and (= (type path) "string")
                   (~= path "")
                   (= (type lnum) "number")
                   (> lnum 0)
                   (or (= side "before") (= side "after"))
                   (> count 0)
                   (~= ref-kind "file-entry"))
          {:path path
           :lnum lnum
           :side side
           :lines (slice-lines current-lines start count)
           :ref-kind ref-kind})))

    (fn append-replace-ops!
      [ops old-rows new-lines common current-rows state]
      (for [i 1 common]
        (let [row (. old-rows i)
              text (or (. new-lines i) "")]
          (when (and (valid-row? row) (~= (or (. row :text) "") text))
            (if (special-projected-row? row)
                (let [err (append-group-op! ops row current-rows (. state :processed-special-groups))]
                  (when err
                    (set (. state :unsafe-structural?) true)))
                (append-op! ops (. row :path) {:kind :replace
                                               :lnum (. row :lnum)
                                               :text text
                                               :old-text (or (. row :text) "")
                                               :ref-kind (or (. row :kind) "")}))))))

    (fn append-delete-ops!
      [ops old-rows common a-count state]
      (when (> a-count common)
        (for [i (+ common 1) a-count]
          (let [row (. old-rows i)]
            (if (and (valid-row? row) (not (special-projected-row? row)))
                (append-op! ops (. row :path) {:kind :delete :lnum (. row :lnum) :ref-kind (or (. row :kind) "")})
                (set (. state :unsafe-structural?) true))))))

    (fn insertion-op
      [session current-rows current-lines b-start common b-count old-rows]
      (or (structural-op-from-current-rows current-rows (+ b-start common) (- b-count common))
          (pending-structural-op session (+ b-start common) (- b-count common) current-lines
            (or (and (. old-rows common) (. (. old-rows common) :kind))
                (and (. old-rows (+ common 1)) (. (. old-rows (+ common 1)) :kind))
                ""))))

    (fn append-insert-ops!
      [ops insert-op state]
      (if insert-op
          (append-op! ops (. insert-op :path)
            {:kind (if (= (. insert-op :side) "before") :insert-before :insert-after)
             :lnum (. insert-op :lnum)
             :lines (. insert-op :lines)
             :ref-kind (or (. insert-op :ref-kind) "")})
          (set (. state :unsafe-structural?) true)))

    (fn handle-modified-hunk!
      [session ops current-rows current-lines state h baseline-rows]
      (let [[a-start a-count b-start b-count] (hunk-indices h)
            common (math.min a-count b-count)
            old-rows (slice-lines baseline-rows a-start a-count)
            new-lines (slice-lines current-lines b-start b-count)]
        (append-replace-ops! ops old-rows new-lines common current-rows state)
        (append-delete-ops! ops old-rows common a-count state)
        (when (> b-count a-count)
          (append-insert-ops!
            ops
            (insertion-op session current-rows current-lines b-start common b-count old-rows)
            state))))

    (fn handle-insert-only-hunk!
      [session ops current-rows current-lines state h]
      (let [[_ _ b-start b-count] (hunk-indices h)]
        (when (> b-count 0)
          (append-insert-ops!
            ops
            (or (structural-op-from-current-rows current-rows b-start b-count)
                (pending-structural-op session b-start b-count current-lines ""))
            state))))

    (fn apply-hunk-file-ops!
      [session ops current-rows current-lines state h baseline-rows]
      (let [[_ a-count _ _] (hunk-indices h)]
        (if (> a-count 0)
            (handle-modified-hunk! session ops current-rows current-lines state h baseline-rows)
            (handle-insert-only-hunk! session ops current-rows current-lines state h))))

    (fn collect-file-ops
      [session]
      (let [meta session.meta
            buf meta.buf.buffer
            baseline-lines (or session.edit-baseline-lines (vim.api.nvim_buf_get_lines buf 0 -1 false))
            baseline-rows (or session.edit-baseline-rows [])
            current-lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
            current-rows (projected-rows-from-edits session baseline-rows baseline-lines current-lines)
            hunks (diff-hunks baseline-lines current-lines)
            ops {}
            state {:unsafe-structural? false
                   :processed-special-groups {}}]
        (set session.live-edit-rows current-rows)
        (each [_ h (ipairs hunks)]
          (apply-hunk-file-ops! session ops current-rows current-lines state h baseline-rows))
        {:ops ops
         :current-lines current-lines
         :current-rows current-rows
         :unsafe-structural? (. state :unsafe-structural?)}))

    (fn grouped-path-ops->flat-ops
      [ops]
      (let [out []]
        (each [path per-file (pairs (or ops {}))]
          (each [_ op (ipairs (or per-file []))]
            (let [item (vim.deepcopy (or op {}))]
              (set (. item :path) path)
              (table.insert out item))))
        out))

    (fn apply-file-ops!
      [ops]
      (source-mod.apply-write-ops! (grouped-path-ops->flat-ops ops)))

    (fn update-row-after-ops
      [row ops post-lines renames]
      (let [ref (vim.deepcopy (or row {}))
            path0 (or (. ref :path) "")
            path (or (. (or renames {}) path0) path0)
            lnum0 (if (and (= (type (. ref :lnum)) "number") (> (. ref :lnum) 0)) (. ref :lnum) 1)
            generated-path (. ref :insert-path)
            generated-lnum (. ref :insert-lnum)
            generated-side (. ref :insert-side)]
        (set (. ref :path) path)
        (var lnum lnum0)
        (each [_ op (ipairs (or (. ops path) []))]
          (let [same-generated? (and (= generated-path path)
                                     (= generated-lnum (. op :lnum))
                                     (or (and (= generated-side "before") (= (. op :kind) :insert-before))
                                         (and (= generated-side "after") (= (. op :kind) :insert-after))))]
            (when-not same-generated?
              (if (= (. op :kind) :insert-before)
                  (when (>= lnum (. op :lnum))
                    (set lnum (+ lnum (# (or (. op :lines) [])))))
                  (= (. op :kind) :insert-after)
                  (when (> lnum (. op :lnum))
                    (set lnum (+ lnum (# (or (. op :lines) [])))))
                  (= (. op :kind) :delete)
                  (when (> lnum (. op :lnum))
                    (set lnum (- lnum 1)))
                  nil))))
        (when (< lnum 1)
          (set lnum 1))
        (set (. ref :lnum) lnum)
        (let [lines (. post-lines path)
              line (or (and lines
                            (>= lnum 1)
                            (<= lnum (# lines))
                            (. lines lnum))
                       (. ref :text)
                       (. ref :line)
                       "")]
          (set (. ref :line) line)
          (set (. ref :text) line))
        ref))

    (fn update-session-refs-after-ops!
      [session current-rows ops post-lines renames]
      (let [meta session.meta
            refs []
            content []
            idxs []]
        (each [_ row (ipairs (or current-rows []))]
          (let [ref (update-row-after-ops row ops post-lines renames)
                idx (+ (# refs) 1)]
            (when (= (or (. ref :kind) "") "file-entry")
              (let [rel (vim.fn.fnamemodify (or (. ref :path) "") ":.")]
                (set (. ref :line) (if (and (= (type rel) "string") (~= rel "")) rel (or (. ref :path) "")))
                (set (. ref :text) (. ref :line))))
            (table.insert refs {:kind (or (. ref :kind) "")
                                :path (or (. ref :path) "")
                                :lnum (or (. ref :lnum) 1)
                                :open-lnum (or (. ref :open-lnum) (. ref :lnum) 1)
                                :source-lnum (. ref :source-lnum)
                                :source-text (. ref :source-text)
                                :source-group-id (. ref :source-group-id)
                                :source-group-kind (. ref :source-group-kind)
                                :transform-chain (vim.deepcopy (or (. ref :transform-chain) []))
                                :line (or (. ref :line) "")})
            (table.insert content (or (. ref :line) ""))
            (table.insert idxs idx)))
        (set meta.buf.source-refs refs)
        (set meta.buf.content content)
        (set meta.buf.indices idxs)))

    (fn invalidate-caches-for-paths!
      [deps session updates]
      (let [{: router} deps
            project-file-cache (and router router.project-file-cache)
            preview-file-cache (or session.preview-file-cache {})
            info-file-head-cache (or session.info-file-head-cache {})
            info-file-meta-cache (or session.info-file-meta-cache {})]
        (set session.preview-file-cache preview-file-cache)
        (set session.info-file-head-cache info-file-head-cache)
        (set session.info-file-meta-cache info-file-meta-cache)
        (each [path _ (pairs (or updates {}))]
          (when project-file-cache
            (set (. project-file-cache path) nil))
          (set (. preview-file-cache path) nil)
          (set (. info-file-head-cache path) nil)
          (set (. info-file-meta-cache path) nil))))

    (fn write-results!
      [deps session sign-mod]
      (let [collected (collect-file-ops session)
            ops (. collected :ops)
            buf session.meta.buf.buffer]
        (if (. collected :unsafe-structural?)
            (do
              (vim.notify
                "metabuffer: only in-place line replacements are writable from results; open the real file for insert/delete edits"
                vim.log.levels.ERROR)
              (events.send :on-query-update!
                {:session session
                 :query (or session.prompt-last-applied-text "")
                 :refresh-lines false
                 :refresh-signs? true}))
            (let [result (apply-file-ops! ops)]
              (set session.pending-structural-edit nil)
              (update-session-refs-after-ops! session (. collected :current-rows) ops (. result :post-lines) (. result :renames))
              (invalidate-caches-for-paths! deps session (. result :paths))
              (when (> result.changed 0)
                (pcall session.meta.on-update 0))
              (pcall vim.api.nvim_set_option_value "modified" false {:buf buf})
              (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" false)
              (events.send :on-query-update!
                {:session session
                 :query (or session.prompt-last-applied-text "")
                 :refresh-lines true
                 :capture-sign-baseline? (not (not sign-mod))
                 :refresh-signs? (not (not sign-mod))})
              (vim.notify
                (if (> result.changed 0)
                    (.. "metabuffer: wrote " (tostring result.changed) " change(s)")
                    "metabuffer: no changes")
                vim.log.levels.INFO)))))

    {:apply-live-edits-to-meta! apply-live-edits-to-meta!
     :write-results! write-results!}))

M
