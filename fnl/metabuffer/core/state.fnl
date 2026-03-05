(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(set M.cases ["smart" "ignore" "normal"])
(set M.syntax-types ["buffer" "meta"])

(fn M.default-condition
  [query]
  "Public API: M.default-condition."
  (let [c (vim.api.nvim_win_get_cursor 0)]
    {:text (or query "")
     :caret-locus (# (or query ""))
     :selected-index (- (. c 1) 1)
     :matcher-index 1
     :case-index 1
     :syntax-index 1
     :restored false}))

(fn M.ignorecase
  [case-mode query]
  "Public API: M.ignorecase."
  (if (= case-mode "ignore")
      true
      (if (= case-mode "normal")
          false
          (= query (string.lower query)))))

M
