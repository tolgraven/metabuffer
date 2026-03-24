(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not}
  :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.split-input
  [text]
  "Public API: M.split-input."
  (vim.split (or text "") "%s+" {:trimempty true}))

(fn M.convert2regex-pattern
  [text]
  "Public API: M.convert2regex-pattern."
  (table.concat (M.split-input text) "\\|"))

(fn M.assign-content
  [buf lines]
  "Public API: M.assign-content."
  (let [view (vim.fn.winsaveview)]
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) true))
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (let [bo (. vim.bo buf)]
      (set (. bo :modifiable) false))
    (vim.fn.winrestview view)))

(fn M.escape-vim-pattern
  [text]
  "Public API: M.escape-vim-pattern."
  (vim.fn.escape (or text "") "\\^$~.*[]"))

(fn M.query-is-lower
  [query]
  "Public API: M.query-is-lower."
  (= (string.lower (or query "")) (or query "")))

(fn M.buf-valid?
  [buf]
  "Public API: M.buf-valid?."
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn M.delete-transient-unnamed-buffer!
  [buf]
  "Best-effort wipe of a temporary unnamed split buffer. Returns true if deleted."
  (if (not (M.buf-valid? buf))
      false
      (let [name (vim.api.nvim_buf_get_name buf)
            lines (vim.api.nvim_buf_line_count buf)
            wins (vim.fn.win_findbuf buf)
            attached? (> (# (or wins [])) 0)]
        (if (and (= (or name "") "")
                 (<= lines 1)
                 (not attached?))
            (let [bo (. vim.bo buf)]
              (set (. bo :buflisted) false)
              (set (. bo :bufhidden) "wipe")
              (set (. bo :swapfile) false)
              (not (not (pcall vim.api.nvim_buf_delete buf {:force true}))))
            false))))

(fn M.mark-transient-unnamed-buffer!
  [buf]
  "Best-effort mark of a temporary unnamed split buffer so it never shows in :ls."
  (when (M.buf-valid? buf)
    (let [name (vim.api.nvim_buf_get_name buf)]
      (when (= (or name "") "")
        (let [bo (. vim.bo buf)]
          (set (. bo :buflisted) false)
          (set (. bo :bufhidden) "wipe")
          (set (. bo :swapfile) false))))))

(fn M.set-buffer-name!
  [buf base-name]
  "Best-effort unique buffer naming. Expected output: assigned name or fallback."
  (if (not (M.buf-valid? buf))
      (or base-name "")
      (let [base (or base-name "metabuffer")
            name0 base]
        (var name name0)
        (var n 1)
        (while (and (> (vim.fn.bufnr name) 0)
                    (~= (vim.fn.bufnr name) buf))
          (set n (+ n 1))
          (set name (.. base " [" n "]")))
        (let [rename! (fn []
                        (vim.cmd (.. "silent noautocmd file " (vim.fn.fnameescape name))))
              [ok] [(pcall vim.api.nvim_buf_call buf rename!)]]
          (if ok
              name
              (let [[ok-api] [(pcall vim.api.nvim_buf_set_name buf name)]]
                (if ok-api
                    name
                    (.. base " [" buf "]"))))))))

(fn M.disable-heavy-buffer-features!
  [buf]
  "Best-effort opt-out of heavy buffer-local helpers on Meta-owned buffers."
  (when (M.buf-valid? buf)
    (pcall vim.api.nvim_buf_set_var buf "conjure_disable" true)
    (pcall vim.api.nvim_buf_set_var buf "lsp_disabled" 1)
    (pcall vim.api.nvim_buf_set_var buf "gitgutter_enabled" 0)
    (pcall vim.api.nvim_buf_set_var buf "gitsigns_disable" true)
    (pcall vim.diagnostic.enable false {:bufnr buf})
    (when (= 1 (vim.fn.exists "*rainbow_parentheses#deactivate"))
      (pcall vim.api.nvim_buf_set_var buf "metabuffer_rainbow_parentheses_disabled" true)
      (let [deactivate! (fn []
                          (vim.cmd "silent! call rainbow_parentheses#deactivate()"))]
        (pcall vim.api.nvim_buf_call buf deactivate!)))))

(fn M.restore-heavy-buffer-features!
  [buf]
  "Undo Meta's best-effort heavy-helper opt-outs on surviving buffers."
  (when (M.buf-valid? buf)
    (let [[ok disabled?] [(pcall vim.api.nvim_buf_get_var buf "metabuffer_rainbow_parentheses_disabled")]]
      (when (and ok disabled? (= 1 (vim.fn.exists "*rainbow_parentheses#activate")))
        (let [activate! (fn []
                          (vim.cmd "silent! call rainbow_parentheses#activate()"))]
          (pcall vim.api.nvim_buf_call buf activate!))
        (pcall vim.api.nvim_buf_del_var buf "metabuffer_rainbow_parentheses_disabled")))))

(fn M.win-valid?
  [win]
  "Public API: M.win-valid?."
  (and win (vim.api.nvim_win_is_valid win)))

(fn M.deepcopy
  [x]
  "Public API: M.deepcopy."
  (vim.deepcopy x))

(fn M.clamp
  [n lo hi]
  "Public API: M.clamp."
  (math.max lo (math.min hi n)))

(fn M.build-group-names
  [prefix count]
  "Public API: M.build-group-names."
  (let [groups []]
    (for [i 1 count]
      (table.insert groups (.. prefix i)))
    groups))

(fn M.ext-from-path
  [path]
  "Public API: M.ext-from-path."
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        dot (string.match file ".*()%.")]
    (if (and dot (> dot 0) (< dot (# file)))
        (string.sub file (+ dot 1))
        "")))

(fn M.devicon-info
  [path fallback-hl]
  "Public API: M.devicon-info."
  (let [file (vim.fn.fnamemodify (or path "") ":t")
        ext (M.ext-from-path path)
        [ok-web web] [(pcall require :nvim-web-devicons)]]
    (if (and ok-web web)
        (let [[ok-i icon icon-hl] [(pcall web.get_icon file ext {:default true})]
              next-hl (if (and ok-i (= (type icon-hl) "string") (~= icon-hl ""))
                          icon-hl
                          fallback-hl)]
          {:icon (if (and ok-i (= (type icon) "string") (~= icon "")) icon "")
           :icon-hl next-hl
           :ext-hl next-hl
           :file-hl fallback-hl})
        (if (= 1 (vim.fn.exists "*WebDevIconsGetFileTypeSymbol"))
            (let [icon (vim.fn.WebDevIconsGetFileTypeSymbol file)]
              {:icon (if (and (= (type icon) "string") (~= icon "")) icon "")
               :icon-hl fallback-hl
               :ext-hl fallback-hl
               :file-hl fallback-hl})
            {:icon ""
             :icon-hl fallback-hl
             :ext-hl fallback-hl
             :file-hl fallback-hl}))))

(fn M.buf-lines
  [buf]
  "Public API: M.buf-lines."
  (vim.api.nvim_buf_get_lines buf 0 -1 false))

(fn M.cursor
  []
  "Public API: M.cursor."
  (vim.api.nvim_win_get_cursor 0))

(fn M.set-cursor
  [row col]
  "Public API: M.set-cursor."
  (vim.api.nvim_win_set_cursor 0 [row (or col 0)]))

M
