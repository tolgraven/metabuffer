(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not}
  :io.gitlab.andreyorst.cljlib.core)
(local M {})
(var mini-icons-cache nil)
(var mini-icons-tried? false)

(fn ensure-mini-icons
  []
  (when-not mini-icons-tried?
    (set mini-icons-tried? true)
    (let [[ok mod] [(pcall require :mini.icons)]]
      (when (and ok mod)
        (set mini-icons-cache mod))))
  (or _G.MiniIcons mini-icons-cache))

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
              (let [(ok) (pcall vim.api.nvim_buf_delete buf {:force true})] ok))
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
        mini (ensure-mini-icons)]
    (if (and mini (= (type (. mini :get)) "function"))
        (let [[ok-i icon icon-hl] [(pcall (. mini :get) "file" file)]
              next-hl (if (and ok-i (= (type icon-hl) "string") (~= icon-hl ""))
                          icon-hl
                          fallback-hl)]
          {:icon (if (and ok-i (= (type icon) "string") (~= icon "")) icon "")
           :icon-hl next-hl
           :ext-hl next-hl
           :file-hl fallback-hl})
        {:icon ""
         :icon-hl fallback-hl
         :ext-hl fallback-hl
         :file-hl fallback-hl})))

(fn first-visible-glyph
  [text]
  (let [s (or text "")]
    (if-let [pos (string.find s "%S")]
      (vim.fn.strcharpart s (- pos 1) 1)
      "")))

(fn marker-sign
  [glyph hl]
  (if (~= (or glyph "") "")
      {:text glyph
       :hl hl
       :highlights [{:start 0 :end (# glyph) :hl hl}]}
      {:text "  " :hl "LineNr"}))

(fn M.icon-sign
  [spec]
  "Return a sign object from an icon spec. Expected output: {:text \"󰈔\" :hl \"MetaSourceFile\"}."
  (let [marker (or spec {})
        mini (ensure-mini-icons)
        icon-result (if (and mini
                             (= (type (. mini :get)) "function")
                             (~= (or (. marker :category) "") ""))
                        [(pcall (. mini :get) (. marker :category) (. marker :name))]
                        [false nil nil])
        [ok glyph hl] icon-result
        text (if (and ok (= (type glyph) "string") (~= glyph ""))
                 glyph
                 (. marker :fallback))
        sign-hl (if (and ok (= (type hl) "string") (~= hl ""))
                    hl
                    (. marker :hl))]
    (marker-sign text sign-hl)))

(fn M.combine-signs
  [primary secondary]
  "Merge two sign descriptors into one 2-cell sign. Expected output: {:text \"󰈔✹\" :highlights [...]}."
  (let [left (first-visible-glyph (and primary primary.text))
        right (first-visible-glyph (and secondary secondary.text))
        left-hl (or (and primary primary.hl) "LineNr")
        right-hl (or (and secondary secondary.hl) "LineNr")
        text (if (~= left "")
                 (if (or (= right "") (>= (vim.fn.strdisplaywidth left) 2))
                     left
                     (.. left right))
                 (if (~= right "") right "  "))
        highs []]
    (when (~= left "")
      (table.insert highs {:start 0 :end (# left) :hl left-hl}))
    (when (and (~= right "") (~= text left))
      (table.insert highs {:start (# left) :end (+ (# left) (# right)) :hl right-hl}))
    {:text text
     :hl (if (~= left "") left-hl right-hl)
     :highlights highs}))

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
