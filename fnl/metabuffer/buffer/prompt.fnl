(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local base-buffer-mod (require :metabuffer.buffer.base))
(local directive-mod (require :metabuffer.query.directive))
(local M {})

(fn set-prompt-completefunc!
  []
  (set _G.__meta_directive_completefunc (. directive-mod :completefunc)))

(fn apply-prompt-buffer-opts!
  [buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (set-prompt-completefunc!)
    (base-buffer-mod.apply-buffer-opts!
      buf
      {:buftype "nofile"
       :bufhidden "hide"
       :swapfile false
       :modifiable true
       :completefunc "v:lua.__meta_directive_completefunc"
       :filetype "metabufferprompt"}))
  buf)

(fn M.prepare-buffer!
  [buf]
  "Apply Meta prompt buffer-local options to BUF. Returns BUF."
  (apply-prompt-buffer-opts! buf))

(fn M.new
  [buf]
  "Register and prepare a prompt buffer. Returns BUF."
  (set-prompt-completefunc!)
  (base-buffer-mod.register-managed-buffer!
    buf
    :prompt
    "[Metabuffer Prompt]"
    {:buftype "nofile"
     :bufhidden "hide"
     :swapfile false
     :modifiable true
     :completefunc "v:lua.__meta_directive_completefunc"
     :filetype "metabufferprompt"}
    nil))

(fn M.sync-name!
  [session]
  "Sync prompt buffer name from the current Meta buffer. Returns target name or nil."
  (when (and session
             session.prompt-buf
             (vim.api.nvim_buf_is_valid session.prompt-buf)
             session.meta
             session.meta.buf
             (= (type session.meta.buf.name) "string")
             (~= session.meta.buf.name ""))
    (let [name (.. session.meta.buf.name " [Prompt]")]
      (pcall vim.api.nvim_buf_set_name session.prompt-buf name)
      name)))

(fn M.clear-modified!
  [buf]
  "Clear modified state for BUF when it is still valid. Returns BUF."
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (pcall vim.api.nvim_set_option_value "modified" false {:buf buf}))
  buf)

M
