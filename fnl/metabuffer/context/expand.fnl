(import-macros {: when-let : if-let : when-some : if-some : when-not : cond} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local util (require :metabuffer.util))
(local events (require :metabuffer.events))

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

(fn apply-ft-buffer-vars!
  [buf ft]
  (when (and buf (vim.api.nvim_buf_is_valid buf) (= ft "fennel"))
    (pcall vim.api.nvim_buf_set_var buf "fennel_lua_version" "5.1")
    (pcall vim.api.nvim_buf_set_var buf "fennel_use_luajit" (if jit 1 0))))

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
  [session ref read-file-lines-cached]
  (if-let [buf (buf-for-ref ref)]
    buf
    (if (and ref ref.path (= 1 (vim.fn.filereadable ref.path)))
      (let [cache (or (and session session.ts-expand-bufs) {})
            _ (when session (set session.ts-expand-bufs cache))
            cached (. cache ref.path)]
        (if (and cached (vim.api.nvim_buf_is_valid cached))
          cached
          (let [buf (vim.api.nvim_create_buf false true)
                ft (filetype-for-ref ref)
                lines (lines-for-ref session ref read-file-lines-cached)]
            (events.send :on-buf-create! {:buf buf :role :context})
            (util.set-buffer-name! buf "[Metabuffer Context]")
            (let [bo (. vim.bo buf)]
              (set (. bo :bufhidden) "hide")
              (set (. bo :buftype) "nofile")
              (set (. bo :swapfile) false))
            (apply-ft-buffer-vars! buf ft)
            (let [bo (. vim.bo buf)]
              (set (. bo :modifiable) true)
              (set (. bo :filetype) (if (~= ft "") ft "text")))
            (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
            (let [bo (. vim.bo buf)]
              (set (. bo :modifiable) false))
            (set (. cache ref.path) buf)
            buf)))
      nil)))

(fn node-type-matches?
  [mode node-type]
  (let [t (string.lower (or node-type ""))]
    (cond
      (= mode "fn")
      (or (= t "fn_form")
          (= t "lambda_form")
          (= t "macro_form")
          (not= nil (string.find t "function" 1 true))
          (not= nil (string.find t "method" 1 true))
          (not= nil (string.find t "func" 1 true))
          (not= nil (string.find t "lambda" 1 true)))
      (= mode "class")
      (or (not= nil (string.find t "class" 1 true))
          (not= nil (string.find t "interface" 1 true))
          (not= nil (string.find t "struct" 1 true))
          (not= nil (string.find t "impl" 1 true))
          (not= nil (string.find t "module" 1 true)))
      (= mode "scope")
      (or (node-type-matches? "fn" t)
          (node-type-matches? "class" t)
          (= t "let_form")
          (= t "when_form")
          (= t "each_form")
          (= t "for_form")
          (= t "while_form")
          (= t "accumulate_form")
          (= t "do_form")
          (not= nil (string.find t "block" 1 true))
          (= t "chunk")
          (= t "program")
          (= t "source_file"))
      true false)))

(fn ts-range-for-mode
  [session ref mode read-file-lines-cached]
  (if-let [buf (ensure-ts-buf session ref read-file-lines-cached)]
    (let [lang (filetype-for-ref ref)
          parser (if (~= (or lang "") "")
                     (vim.treesitter.get_parser buf lang)
                     (vim.treesitter.get_parser buf))
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
        line (or (. lines (or ref.lnum 1))
                 ref.line
                 "")]
    (or (string.match line "[%a_][%w_%.:]*")
        "")))

(fn exact-word-find?
  [line word]
  (let [pat (.. "%f[%w_]" (vim.pesc (or word "")) "%f[^%w_]")]
    (and (~= (or word "") "")
         (not= nil (string.find (or line "") pat)))))

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
      (= norm "env") (ts-range-for-mode session ref "scope" read-file-lines-cached)
      (or (= norm "fn") (= norm "class") (= norm "scope"))
      (ts-range-for-mode session ref norm read-file-lines-cached)
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

(fn index-refs-by-path
  [refs]
  (let [by-path {}]
    (each [idx ref (ipairs (or refs []))]
      (when (and ref
                 (~= (or ref.kind "") "file-entry")
                 (= (type ref.path) "string")
                 (~= ref.path "")
                 ref.lnum)
        (when-not (. by-path ref.path)
          (set (. by-path ref.path) []))
        (table.insert (. by-path ref.path) {:idx idx :lnum ref.lnum :line (or ref.line "") :ref ref})))
    by-path))

(fn append-range-indices!
  [out seen items start-lnum end-lnum]
  (each [_ item (ipairs (or items []))]
    (when (and (>= item.lnum start-lnum)
               (<= item.lnum end-lnum)
               (not (. seen item.idx)))
      (set (. seen item.idx) true)
      (table.insert out item.idx))))

(fn append-usage-indices!
  [session out seen refs read-file-lines-cached]
  (let [needle (identifier-at-ref session (. refs 1) read-file-lines-cached)]
    (when (~= needle "")
      (each [_ ref (ipairs (or (and session session.meta session.meta.buf session.meta.buf.source-refs) refs))]
        (when (and ref
                   ref.idx
                   ref.lnum
                   (~= (or ref.kind "") "file-entry")
                   (exact-word-find? (or ref.line "") needle)
                   (not (. seen ref.idx)))
          (set (. seen ref.idx) true)
          (table.insert out ref.idx))))))

(fn mode-range
  [session ref mode read-file-lines-cached around]
  (let [lines (lines-for-ref session ref read-file-lines-cached)
        total (# lines)
        norm (normalized-mode mode)]
    (cond
      (= norm "none") nil
      (= norm "usage") nil
      (= norm "env") (ts-range-for-mode session ref "scope" read-file-lines-cached)
      (or (= norm "fn") (= norm "class") (= norm "scope"))
      (ts-range-for-mode session ref norm read-file-lines-cached)
      true (fallback-range ref norm total around))))

(fn M.expanded-indices
  [session indices refs opts]
  (let [mode (normalized-mode (. opts :mode))
        read-file-lines-cached (. opts :read-file-lines-cached)
        around (or (. opts :around-lines) 3)
        max-blocks (math.max 1 (or (. opts :max-blocks) 24))
        refs-with-idx (let [out0 []]
                        (each [idx ref (ipairs (or refs []))]
                          (let [next (if ref
                                         (vim.tbl_extend "force" ref {:idx idx})
                                         {:idx idx})]
                            (table.insert out0 next)))
                        out0)
        by-path (index-refs-by-path refs-with-idx)
        out []
        seen {}]
    (cond
      (= mode "none") (vim.deepcopy (or indices []))
      (= mode "usage")
      (let [hit-refs []]
        (each [_ idx (ipairs (or indices []))]
          (let [ref (. refs-with-idx idx)]
            (when (and ref (~= (or ref.kind "") "file-entry"))
              (table.insert hit-refs ref))))
        (append-usage-indices! session out seen hit-refs read-file-lines-cached))
      true
      (each [_ idx (ipairs (or indices []))]
        (when (< (# out) (* max-blocks 400))
          (let [ref (. refs-with-idx idx)
                path (and ref ref.path)
                items (. by-path path)]
            (when (and ref items (~= (or ref.kind "") "file-entry"))
              (if-let [rng (mode-range session ref mode read-file-lines-cached around)]
                (append-range-indices! out seen items rng.start rng.end)
                (when-not (. seen idx)
                  (set (. seen idx) true)
                  (table.insert out idx))))))))
    (when (= (# out) 0)
      (each [_ idx (ipairs (or indices []))]
        (when-not (. seen idx)
          (set (. seen idx) true)
          (table.insert out idx))))
    out))

M
