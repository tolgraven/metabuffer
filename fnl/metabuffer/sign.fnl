(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(local change-sign-group "MetaBufferChanges")
(local sign-added "MetaBufLineAdded")
(local sign-modified "MetaBufLineModified")
(local sign-removed "MetaBufLineRemoved")

(fn ensure-change-signs-defined!
  []
  (pcall vim.fn.sign_define sign-added {:text "✚" :texthl "MetaBufSignAdded"})
  (pcall vim.fn.sign_define sign-modified {:text "✹" :texthl "MetaBufSignModified"})
  (pcall vim.fn.sign_define sign-removed {:text "" :texthl "MetaBufSignRemoved"}))

(fn bvar
  [buf name default]
  (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf name)]]
    (if ok v default)))

(fn current-lines
  [buf]
  (if (and buf (vim.api.nvim_buf_is_valid buf))
      (vim.api.nvim_buf_get_lines buf 0 -1 false)
      []))

(fn place-sign!
  [buf id name lnum]
  (when (and buf (vim.api.nvim_buf_is_valid buf) (> lnum 0))
    (pcall vim.fn.sign_place id change-sign-group name buf {:lnum lnum :priority 20})))

(fn snapshot-rows
  [session]
  (let [meta (and session session.meta)
        idxs (or (and meta meta.buf meta.buf.indices) [])
        refs (or (and meta meta.buf meta.buf.source-refs) [])
        content (or (and meta meta.buf meta.buf.content) [])
        rows []]
    (each [_ src-idx (ipairs idxs)]
      (let [ref (and src-idx (. refs src-idx))]
        (table.insert rows
          {:src-idx src-idx
           :kind (or (and ref ref.kind) "")
           :path (or (and ref ref.path) "")
           :lnum (and ref ref.lnum)
           :text (or (and ref ref.line)
                     (and src-idx (. content src-idx))
                     "")})))
    rows))

(fn hunk-indices
  [h]
  (let [a-start (or (. h 1) 1)
        a-count (or (. h 2) 0)
        b-start (or (. h 3) 1)
        b-count (or (. h 4) 0)]
    [a-start a-count b-start b-count]))

(fn diff-hunks
  [old-lines new-lines]
  (let [old-text (table.concat (or old-lines []) "\n")
        new-text (table.concat (or new-lines []) "\n")
        [ok out] [(pcall vim.diff old-text new-text {:result_type "indices" :algorithm "histogram"})]]
    (if (and ok (= (type out) "table")) out [])))

(fn place-hunk-signs!
  [buf line-count id-start h]
  (let [[a-start a-count b-start b-count] (hunk-indices h)
        common (math.min a-count b-count)]
    (var next-id id-start)
    (for [i 0 (- common 1)]
      (place-sign! buf next-id sign-modified (+ b-start i))
      (set next-id (+ next-id 1)))
    (when (> b-count a-count)
      (for [i common (- b-count 1)]
        (place-sign! buf next-id sign-added (+ b-start i))
        (set next-id (+ next-id 1))))
    (when (> a-count b-count)
      (let [row (math.max 1 (math.min (math.max 1 line-count) (+ b-start common)))]
        (place-sign! buf next-id sign-removed row)
        (set next-id (+ next-id 1))))
    next-id))

(fn M.buf-has-signs?
  [buf]
  "Public API: M.buf-has-signs?."
  (let [out (vim.fn.execute (.. "sign place group=* buffer=" buf))]
    (> (# out) 2)))

(fn M.clear-change-signs!
  [buf]
  "Public API: M.clear-change-signs!."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.fn.sign_unplace change-sign-group {:buffer buf})))

(fn M.refresh-change-signs!
  [session]
  "Public API: M.refresh-change-signs!."
  (let [meta (and session session.meta)
        buf (and meta meta.buf meta.buf.buffer)]
    (when (and buf (vim.api.nvim_buf_is_valid buf)
               (not (bvar buf "meta_internal_render" false)))
      (let [manual-edit? (bvar buf "meta_manual_edit_active" false)]
        (if (not manual-edit?)
            (M.clear-change-signs! buf)
            (do
              (ensure-change-signs-defined!)
              (M.clear-change-signs! buf)
              (let [old-lines (or session.edit-baseline-lines [])
                    new-lines (current-lines buf)
                    hunks (diff-hunks old-lines new-lines)]
                (var next-id 1)
                (each [_ h (ipairs hunks)]
                  (set next-id (place-hunk-signs! buf (# new-lines) next-id h))))))))))

(fn M.capture-baseline!
  [session]
  "Public API: M.capture-baseline!."
  (let [meta (and session session.meta)
        buf (and meta meta.buf meta.buf.buffer)]
    (when (and buf (vim.api.nvim_buf_is_valid buf))
      (set session.edit-baseline-lines (vim.deepcopy (current-lines buf)))
      (set session.edit-baseline-rows (snapshot-rows session)))))

(fn M.refresh-dummy
  [buf]
  "Public API: M.refresh-dummy."
  (pcall vim.cmd "sign define MetaDummy")
  (pcall vim.cmd (.. "sign unplace 9999 buffer=" buf))
  (pcall vim.cmd (.. "sign place 9999 line=1 name=MetaDummy buffer=" buf)))

M
