(local tracked-bufs {})

(fn buf-valid?
  [buf]
  (and buf (vim.api.nvim_buf_is_valid buf)))

(fn get-buf-var
  [buf key]
  (let [[ok value] [(pcall vim.api.nvim_buf_get_var buf key)]]
    (if ok value vim.NIL)))

(fn set-buf-var!
  [buf key value]
  (pcall vim.api.nvim_buf_set_var buf key value))

(fn del-buf-var!
  [buf key]
  (pcall vim.api.nvim_buf_del_var buf key))

(fn ensure-buf-state
  [buf]
  (let [state (or (. tracked-bufs buf) {:count 0 :saved {}})]
    (when (= (. tracked-bufs buf) nil)
      (tset tracked-bufs buf state))
    state))

(local conjure-vars
  ["conjure_disable"
   "conjure#client_on_load"
   "conjure#mapping#enable_ft_mappings"
   "conjure#mapping#enable_defaults"
   "conjure#mapping#doc_word"
   "conjure#log#hud#enabled"])

(fn apply-conjure-compat!
  [{: buf}]
  "Disable Conjure buffer-local setup and HUD on Meta-owned buffers."
  (when (buf-valid? buf)
    (let [state (ensure-buf-state buf)
          saved (. state :saved)]
      (when (= state.count 0)
        (each [_ key (ipairs conjure-vars)]
          (tset saved key (get-buf-var buf key)))
        (set (. saved :omnifunc) (. (. vim.bo buf) :omnifunc)))
      (set state.count (+ 1 (or state.count 0)))
      (set-buf-var! buf "conjure_disable" true)
      (set-buf-var! buf "conjure#client_on_load" false)
      (set-buf-var! buf "conjure#mapping#enable_ft_mappings" false)
      (set-buf-var! buf "conjure#mapping#enable_defaults" false)
      (set-buf-var! buf "conjure#mapping#doc_word" false)
      (set-buf-var! buf "conjure#log#hud#enabled" false)
      (let [bo (. vim.bo buf)]
        (set (. bo :omnifunc) "")))))

(fn restore-conjure-compat!
  [{: buf}]
  "Restore Conjure-related buffer-local state when Meta stops owning a buffer."
  (when (buf-valid? buf)
    (let [state (. tracked-bufs buf)]
      (when state
        (set state.count (math.max 0 (- (or state.count 0) 1)))
        (when (= state.count 0)
          (let [saved (. state :saved)]
            (each [_ key (ipairs conjure-vars)]
              (let [value (. saved key)]
                (if (= value vim.NIL)
                    (del-buf-var! buf key)
                    (set-buf-var! buf key value))))
            (let [bo (. vim.bo buf)]
              (if (= (. saved :omnifunc) vim.NIL)
                  (set (. bo :omnifunc) "")
                  (set (. bo :omnifunc) (or (. saved :omnifunc) "")))))
          (tset tracked-bufs buf nil))))))

(fn restore-all!
  [_]
  "Best-effort restore for any tracked buffers if session teardown skipped detach events."
  (each [buf _ (pairs tracked-bufs)]
    (restore-conjure-compat! {:buf buf})))

{:name :conjure
 :domain :compat
 :events
 {:on-buf-create! [{:handler apply-conjure-compat! :priority 12}]
  :on-buf-teardown! [{:handler restore-conjure-compat! :priority 88}]
  :on-session-stop! [{:handler restore-all! :priority 89}]}}
