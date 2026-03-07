(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(local history-file
  (.. (vim.fn.stdpath "data") "/metabuffer_prompt_history.json"))

(fn read-store
  []
  (if (= 1 (vim.fn.filereadable history-file))
      (let [raw (table.concat (vim.fn.readfile history-file) "\n")
            [ok data] [(pcall vim.json.decode raw)]]
        (if (and ok (= (type data) "table"))
            data
            {}))
      {}))

(fn write-store!
  [history saved]
  (let [payload {:history (or history [])
                 :saved (or saved {})}
        [ok json] [(pcall vim.json.encode payload)]]
    (when ok
      (pcall vim.fn.mkdir (vim.fn.fnamemodify history-file ":h") "p")
      (pcall vim.fn.writefile [json] history-file))))

(fn ensure-loaded!
  []
  (when (not vim.g.metabuffer_history_loaded)
    (let [store (read-store)
          loaded-history (if (= (type (. store :history)) "table")
                             (. store :history)
                             [])
          loaded-saved (if (= (type (. store :saved)) "table")
                           (. store :saved)
                           {})]
      (set vim.g.metabuffer_prompt_history
        (if (= (type vim.g.metabuffer_prompt_history) "table")
            vim.g.metabuffer_prompt_history
            loaded-history))
      (set vim.g.metabuffer_saved_prompts
        (if (= (type vim.g.metabuffer_saved_prompts) "table")
            vim.g.metabuffer_saved_prompts
            loaded-saved))
      (set vim.g.metabuffer_history_loaded true))))

(fn M.list
  []
  "Public API: M.list."
  (ensure-loaded!)
  (if (= (type vim.g.metabuffer_prompt_history) "table")
      vim.g.metabuffer_prompt_history
      (do
        (set vim.g.metabuffer_prompt_history [])
        vim.g.metabuffer_prompt_history)))

(fn M.saved
  []
  "Public API: M.saved."
  (ensure-loaded!)
  (if (= (type vim.g.metabuffer_saved_prompts) "table")
      vim.g.metabuffer_saved_prompts
      (do
        (set vim.g.metabuffer_saved_prompts {})
        vim.g.metabuffer_saved_prompts)))

(fn persist!
  []
  (write-store! (M.list) (M.saved)))

(fn M.push!
  [text max-items]
  "Public API: M.push!."
  (when (and (= (type text) "string") (~= (vim.trim text) ""))
    ;; vim.g table values are copied on read; write back after mutation.
    (let [h (vim.deepcopy (M.list))]
      (when (or (= (# h) 0) (~= (. h (# h)) text))
        (table.insert h text))
      (while (> (# h) (or max-items 100))
        (table.remove h 1))
      (set vim.g.metabuffer_prompt_history h)
      (persist!))))

(fn M.save-tag!
  [tag prompt]
  "Public API: M.save-tag!."
  (when (and (= (type tag) "string")
             (~= (vim.trim tag) "")
             (= (type prompt) "string")
             (~= (vim.trim prompt) ""))
    (let [saved (vim.deepcopy (M.saved))]
      (set (. saved (vim.trim tag)) prompt)
      (set vim.g.metabuffer_saved_prompts saved)
      (persist!))))

(fn M.saved-entry
  [tag]
  "Public API: M.saved-entry."
  (when (and (= (type tag) "string") (~= (vim.trim tag) ""))
    (. (M.saved) (vim.trim tag))))

(fn M.saved-items
  []
  "Public API: M.saved-items."
  (let [saved (M.saved)
        tags []]
    (each [k _ (pairs saved)]
      (table.insert tags k))
    (table.sort tags)
    (let [out []]
      (each [_ tag (ipairs tags)]
        (table.insert out {:tag tag :prompt (or (. saved tag) "")}))
      out)))

(fn M.entry
  [idx]
  "Public API: M.entry."
  (let [h (M.list)
        n (# h)]
    (when (and (> idx 0) (<= idx n))
      (. h (+ (- n idx) 1)))))

M
