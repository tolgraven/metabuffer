(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local expand-mod (require :metabuffer.context.expand))
(local path-hl (require :metabuffer.path_highlight))

(local M {})

(fn statusline-text
  [mode total shown]
  (.. "%#StatusLine# Context "
      "%#MetaStatuslinePathFile#" (string.upper (or mode ""))
      "%#StatusLine# "
      (tostring shown) "/" (tostring total) " "))

(fn line-prefix
  [lnum]
  (string.format "%4d " (or lnum 1)))

(fn render-block
  [block]
  (let [path (vim.fn.fnamemodify (or block.path "") ":~:.")
        header (.. path ":" (tostring block.start-lnum) "-" (tostring block.end-lnum))
        out [{:text header :kind "header" :block block}]]
    (each [idx line (ipairs (or block.lines []))]
      (let [lnum (+ block.start-lnum idx -1)]
        (table.insert out {:text (.. (line-prefix lnum) (or line ""))
                           :kind "line"
                           :block block
                           :lnum lnum})))
    out))

(fn flatten-blocks
  [blocks]
  (let [out []]
    (each [_ block (ipairs (or blocks []))]
      (each [_ line (ipairs (render-block block))]
        (table.insert out line))
      (table.insert out {:text "" :kind "spacer"}))
    out))

(fn apply-highlights!
  [buf ns lines]
  (vim.api.nvim_buf_clear_namespace buf ns 0 -1)
  (each [row item (ipairs (or lines []))]
    (let [row0 (- row 1)
          text (or item.text "")]
      (if (= item.kind "header")
          (let [prefix (line-prefix item.block.start-lnum)
                prefix-len 0
                parts (vim.fn.fnamemodify (or item.block.path "") ":~:.")
                dir (let [d (vim.fn.fnamemodify parts ":h")]
                      (if (or (= d ".") (= d "")) "" (.. d "/")))
                file (vim.fn.fnamemodify parts ":t")
                dir-ranges (path-hl.ranges-for-dir dir 0)
                file-start (# dir)]
            (each [_ dr (ipairs dir-ranges)]
              (vim.api.nvim_buf_add_highlight buf ns dr.hl row0 dr.start dr.end))
            (when (> (# file) 0)
              (vim.api.nvim_buf_add_highlight buf ns "MetaSourceFile" row0 file-start (+ file-start (# file)))))
          (= item.kind "line")
          (vim.api.nvim_buf_add_highlight buf ns "MetaSourceLineNr" row0 0 5)
          nil))))

(fn ensure-window!
  [session height]
  (when-not (and session.context-win (vim.api.nvim_win_is_valid session.context-win))
    (let [buf (if (and session.context-buf (vim.api.nvim_buf_is_valid session.context-buf))
                  session.context-buf
                  (vim.api.nvim_create_buf false true))
          win-id (vim.api.nvim_win_call
                   session.meta.win.window
                   (fn []
                     (vim.cmd "belowright split")
                     (vim.api.nvim_get_current_win)))]
      (set session.context-buf buf)
      (set session.context-win win-id)
      (pcall vim.api.nvim_win_set_buf win-id buf)
      (pcall vim.api.nvim_win_set_height win-id height)
      (let [bo (. vim.bo buf)]
        (set (. bo :bufhidden) "hide")
        (set (. bo :buftype) "nofile")
        (set (. bo :swapfile) false)
        (set (. bo :modifiable) false)
        (set (. bo :filetype) "metabuffer"))
      (pcall vim.api.nvim_set_option_value "number" false {:win win-id})
      (pcall vim.api.nvim_set_option_value "relativenumber" false {:win win-id})
      (pcall vim.api.nvim_set_option_value "wrap" false {:win win-id})
      (pcall vim.api.nvim_set_option_value "cursorline" true {:win win-id})
      (pcall vim.api.nvim_set_option_value "signcolumn" "no" {:win win-id})
      (pcall vim.api.nvim_set_option_value "statusline" "%#StatusLine# Context " {:win win-id}))))

(fn close-window!
  [session]
  (when (and session.context-win (vim.api.nvim_win_is_valid session.context-win))
    (pcall vim.api.nvim_win_close session.context-win true))
  (set session.context-win nil)
  (set session.context-buf nil))

(fn visible-hit-refs
  [session]
  (let [meta session.meta
        refs (or meta.buf.source-refs [])
        idxs (or meta.buf.indices [])
        out []]
    (each [_ idx (ipairs idxs)]
      (let [ref (. refs idx)]
        (when (and ref (~= (or ref.kind "") "file-entry"))
          (table.insert out ref))))
    out))

(fn M.new
  [opts]
  (let [read-file-lines-cached (. opts :read-file-lines-cached)
        height-fn (. opts :height-fn)
        max-blocks (. opts :max-blocks)
        around-lines (. opts :around-lines)]
    (let [ns (vim.api.nvim_create_namespace "metabuffer_context")]
      {:update!
       (fn [session]
         (let [mode (expand-mod.normalized-mode (or session.expansion-mode "none"))]
           (if (or session.ui-hidden (= mode "none"))
               (close-window! session)
               (let [refs (visible-hit-refs session)
                     blocks (expand-mod.context-blocks
                              session
                              refs
                              {:mode mode
                               :read-file-lines-cached read-file-lines-cached
                               :around-lines around-lines
                               :max-blocks max-blocks})
                     rendered (flatten-blocks blocks)
                     lines (let [out []]
                             (each [_ item (ipairs rendered)]
                               (table.insert out (or item.text "")))
                             out)]
                 (if (= (# blocks) 0)
                     (close-window! session)
                     (do
                       (ensure-window! session (height-fn session))
                       (when (and session.context-buf (vim.api.nvim_buf_is_valid session.context-buf))
                         (let [bo (. vim.bo session.context-buf)]
                           (set (. bo :modifiable) true))
                         (vim.api.nvim_buf_set_lines session.context-buf 0 -1 false lines)
                         (let [bo (. vim.bo session.context-buf)]
                           (set (. bo :modifiable) false))
                         (apply-highlights! session.context-buf ns rendered)
                         (pcall vim.api.nvim_set_option_value
                                "statusline"
                                (statusline-text mode (# refs) (# blocks))
                                {:win session.context-win}))))))))
       :close-window! close-window!})))

M
