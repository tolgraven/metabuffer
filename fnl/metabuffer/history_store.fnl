(local M {})

(fn M.list []
  (if (= (type vim.g.metabuffer_prompt_history) "table")
      vim.g.metabuffer_prompt_history
      (do
        (set vim.g.metabuffer_prompt_history [])
        vim.g.metabuffer_prompt_history)))

(fn M.push! [text max-items]
  (when (and (= (type text) "string") (~= (vim.trim text) ""))
    ;; vim.g table values are copied on read; write back after mutation.
    (local h (vim.deepcopy (M.list)))
    (if (or (= (# h) 0) (~= (. h (# h)) text))
        (table.insert h text))
    (while (> (# h) (or max-items 100))
      (table.remove h 1))
    (set vim.g.metabuffer_prompt_history h)))

(fn M.entry [idx]
  (let [h (M.list)
        n (# h)]
    (if (and (> idx 0) (<= idx n))
        (. h (+ (- n idx) 1))
        nil)))

M
