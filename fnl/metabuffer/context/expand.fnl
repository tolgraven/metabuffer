(import-macros {: when-let : if-let : when-some : if-some : when-not : cond} :io.gitlab.andreyorst.cljlib.core)

(local M {})

(fn buf-for-ref
  [ref]
  (when (and ref ref.buf (vim.api.nvim_buf_is_valid ref.buf))
    ref.buf))

(fn filetype-for-ref
  [ref]
  (if-let [buf (buf-for-ref ref)]
    (. (. vim.bo buf) :filetype)
    (if-let [path (and ref ref.path)]
      (let [[ok ft] [(pcall vim.filetype.match {:filename path})]]
        (if (and ok (= (type ft) "string")) ft ""))
      "")))

(fn lines-for-ref
  [session ref read-file-lines-cached]
  (if-let [buf (buf-for-ref ref)]
    (vim.api.nvim_buf_get_lines buf 0 -1 false)
    (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
      (let [lines (read-file-lines-cached
                    ref.path
                    {:include-binary (and session session.effective-include-binary)
                     :hex-view (and session session.effective-include-hex)})]
        (if (= (type lines) "table") lines []))
      [])))

(fn ensure-ts-buf
  [ref]
  (if-let [buf (buf-for-ref ref)]
    buf
    (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
      (let [buf (vim.fn.bufadd ref.path)]
        (pcall vim.fn.bufload buf)
        (if (vim.api.nvim_buf_is_valid buf) buf nil))
      nil)))

(fn node-type-matches?
  [mode node-type]
  (let [t (string.lower (or node-type ""))]
    (cond
      (= mode "fn")
      (or (not (not (string.find t "function" 1 true)))
          (not (not (string.find t "method" 1 true)))
          (not (not (string.find t "func" 1 true))))
      (= mode "class")
      (or (not (not (string.find t "class" 1 true)))
          (not (not (string.find t "interface" 1 true)))
          (not (not (string.find t "struct" 1 true)))
          (not (not (string.find t "impl" 1 true)))
          (not (not (string.find t "module" 1 true))))
      (= mode "scope")
      (or (node-type-matches? "fn" t)
          (node-type-matches? "class" t)
          (not (not (string.find t "block" 1 true)))
          (= t "chunk")
          (= t "program")
          (= t "source_file"))
      true false)))

(fn ts-range-for-mode
  [ref mode]
  (if-let [buf (ensure-ts-buf ref)]
    (let [parser (vim.treesitter.get_parser buf)
          trees (and parser ((. parser :parse) parser))
          tree (and trees (. trees 1))
          root (and tree ((. tree :root) tree))
          row (math.max 0 (- (or ref.lnum 1) 1))
          node (and root ((. root :named_descendant_for_range) root row 0 row 0))]
      (when node
        (var cur node)
        (var found nil)
        (while (and cur (not found))
          (when (node-type-matches? mode ((. cur :type) cur))
            (set found cur))
          (set cur ((. cur :parent) cur)))
        (when found
          (let [[sr _ er _] [((. found :range) found)]]
            {:start (+ sr 1) :end (+ er 1)}))))
    nil))

(fn identifier-at-ref
  [session ref read-file-lines-cached]
  (let [lines (lines-for-ref session ref read-file-lines-cached)
        line (or (. lines (or ref.lnum 1)) (or ref.line ""))]
    (or (string.match line "[%a_][%w_%.:]*")
        "")))

(fn exact-word-find?
  [line word]
  (let [pat (.. "%f[%w_]" (vim.pesc (or word "")) "%f[^%w_]")]
    (and (~= (or word "") "")
         (not (not (string.find (or line "") pat))))))

(fn around-range
  [ref total around]
  (let [lnum (math.max 1 (or ref.lnum 1))]
    {:start (math.max 1 (- lnum around))
     :end (math.min total (+ lnum around))}))

(fn fallback-range
  [ref mode total around]
  (cond
    (= mode "line") {:start (math.max 1 (or ref.lnum 1)) :end (math.max 1 (or ref.lnum 1))}
    (= mode "file") {:start 1 :end (math.max 1 total)}
    true (around-range ref total around)))

(fn normalized-mode
  [mode]
  (let [m (string.lower (vim.trim (or mode "")))]
    (cond
      (or (= m "") (= m "none") (= m "off")) "none"
      (or (= m "line") (= m "lines")) "line"
      (or (= m "around") (= m "ctx") (= m "context")) "around"
      (or (= m "fn") (= m "function") (= m "method")) "fn"
      (or (= m "class") (= m "type")) "class"
      (or (= m "scope") (= m "block")) "scope"
      (or (= m "file") (= m "buffer")) "file"
      (or (= m "usage") (= m "usages") (= m "refs") (= m "references")) "usage"
      (= m "env") "env"
      true m)))

(fn expansion-range
  [session ref mode read-file-lines-cached around]
  (let [lines (lines-for-ref session ref read-file-lines-cached)
        total (# lines)
        norm (normalized-mode mode)]
    (cond
      (= norm "none") nil
      (= norm "usage") nil
      (= norm "env") (or (ts-range-for-mode ref "scope")
                         (fallback-range ref "around" total around))
      (or (= norm "fn") (= norm "class") (= norm "scope"))
      (or (ts-range-for-mode ref norm)
          (fallback-range ref "around" total around))
      true (fallback-range ref norm total around))))

(fn block-key
  [ref start-lnum end-lnum mode]
  (.. (or ref.path "") "|" (tostring start-lnum) "|" (tostring end-lnum) "|" (or mode "")))

(fn append-usage-blocks!
  [session blocks seen refs read-file-lines-cached around max-blocks]
  (when (< (# blocks) max-blocks)
    (let [needle (identifier-at-ref session (. refs 1) read-file-lines-cached)]
      (when (~= needle "")
        (each [_ ref (ipairs (or (and session session.meta session.meta.buf session.meta.buf.source-refs) refs))]
          (when (< (# blocks) max-blocks)
            (let [lines (lines-for-ref session ref read-file-lines-cached)
                  total (# lines)]
              (when (and ref
                         (~= (or ref.kind "") "file-entry")
                         (> total 0)
                         (exact-word-find? (or (. lines (or ref.lnum 1)) "") needle))
                (let [rng (around-range ref total around)
                      key (block-key ref rng.start rng.end "usage")]
                  (when-not (. seen key)
                    (set (. seen key) true)
                    (table.insert blocks
                      {:ref ref
                       :mode "usage"
                       :path (or ref.path "")
                       :start-lnum rng.start
                       :end-lnum rng.end
                       :focus-lnum (or ref.lnum 1)
                       :lines (vim.list_slice lines rng.start rng.end)
                       :label (.. "usage:" needle)})))))))))))

(fn append-env-blocks!
  [session blocks seen refs read-file-lines-cached around max-blocks]
  (when (< (# blocks) max-blocks)
    (each [_ ref (ipairs refs)]
      (when (< (# blocks) max-blocks)
        (when-let [rng (expansion-range session ref "env" read-file-lines-cached around)]
          (let [lines (lines-for-ref session ref read-file-lines-cached)
                key (block-key ref rng.start rng.end "env")]
            (when-not (. seen key)
              (set (. seen key) true)
              (table.insert blocks
                {:ref ref
                 :mode "env"
                 :path (or ref.path "")
                 :start-lnum rng.start
                 :end-lnum rng.end
                 :focus-lnum (or ref.lnum 1)
                 :lines (vim.list_slice lines rng.start rng.end)
                 :label "env"}))))))))

(fn M.normalized-mode
  [mode]
  (normalized-mode mode))

(fn M.context-blocks
  [session refs opts]
  (let [mode (normalized-mode (. opts :mode))
        read-file-lines-cached (. opts :read-file-lines-cached)
        around (or (. opts :around-lines) 3)
        max-blocks (math.max 1 (or (. opts :max-blocks) 24))
        blocks []
        seen {}]
    (cond
      (= mode "none") []
      (= mode "usage")
      (append-usage-blocks! session blocks seen refs read-file-lines-cached around max-blocks)
      (= mode "env")
      (append-env-blocks! session blocks seen refs read-file-lines-cached around max-blocks)
      true
      (each [_ ref (ipairs (or refs []))]
        (when (< (# blocks) max-blocks)
          (when-let [rng (expansion-range session ref mode read-file-lines-cached around)]
            (let [lines (lines-for-ref session ref read-file-lines-cached)
                  key (block-key ref rng.start rng.end mode)]
              (when-not (. seen key)
                (set (. seen key) true)
                (table.insert blocks
                  {:ref ref
                   :mode mode
                   :path (or ref.path "")
                   :start-lnum rng.start
                   :end-lnum rng.end
                   :focus-lnum (or ref.lnum 1)
                   :lines (vim.list_slice lines rng.start rng.end)
                   :label mode})))))))
    blocks))

M
