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

(fn place-sign!
  [buf id name lnum]
  (when (and buf (vim.api.nvim_buf_is_valid buf) (> lnum 0))
    (pcall vim.fn.sign_place id change-sign-group name buf {:lnum lnum :priority 20})))

(fn ref-baseline-line
  [session src-idx]
  (let [refs (and session session.meta session.meta.buf session.meta.buf.source-refs)
        ref (and refs src-idx (. refs src-idx))
        line (and ref ref.line)]
    (if (= (type line) "string")
        line
        (let [content (and session session.meta session.meta.buf session.meta.buf.content)]
          (or (and content src-idx (. content src-idx)) "")))))

(fn diff-sign-events
  [session buf]
  (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
        idxs (or (and session session.meta session.meta.buf session.meta.buf.indices) [])
        line-count (# lines)
        idx-count (# idxs)
        max-count (math.max line-count idx-count)
        out []]
    (for [i 1 max-count]
      (if (> i line-count)
        (when (> line-count 0)
          (table.insert out {:kind :removed :lnum line-count}))
        (> i idx-count)
        (table.insert out {:kind :added :lnum i})
        (let [src-idx (. idxs i)
              baseline (ref-baseline-line session src-idx)
              shown (or (. lines i) "")]
          (when (~= shown baseline)
            (table.insert out {:kind :modified :lnum i})))))
    out))

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
      (ensure-change-signs-defined!)
      (M.clear-change-signs! buf)
      (let [events (diff-sign-events session buf)
            id 1]
        (var next-id id)
        (each [_ ev (ipairs events)]
          (if (= ev.kind :added)
              (place-sign! buf next-id sign-added ev.lnum)
              (= ev.kind :removed)
              (place-sign! buf next-id sign-removed ev.lnum)
              (place-sign! buf next-id sign-modified ev.lnum))
          (set next-id (+ next-id 1)))))))

(fn M.refresh-dummy
  [buf]
  "Public API: M.refresh-dummy."
  (pcall vim.cmd "sign define MetaDummy")
  (pcall vim.cmd (.. "sign unplace 9999 buffer=" buf))
  (pcall vim.cmd (.. "sign place 9999 line=1 name=MetaDummy buffer=" buf)))

M
