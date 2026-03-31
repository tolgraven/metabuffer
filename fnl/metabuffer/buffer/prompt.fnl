(import-macros {: when-let : if-let} :io.gitlab.andreyorst.cljlib.core)
(local base-buffer-mod (require :metabuffer.buffer.base))
(local directive-mod (require :metabuffer.query.directive))
(local query-mod (require :metabuffer.query))
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
  (base-buffer-mod.clear-modified! buf))

(fn control-token-style
  [option-prefix tok]
  (let [token (or tok "")
        prefix (option-prefix)
        escaped-prefix? (and (vim.startswith token "\\")
                             (vim.startswith (string.sub token 2) prefix))
        parsed (and (not escaped-prefix?)
                    (directive-mod.parse-token prefix token))
        off? (and parsed (= (. parsed :value) false))
        provider-type (or (and parsed (. parsed :provider-type)) "")
        functional? (or (= provider-type "transform")
                        (= (or (and parsed (. parsed :token-key)) "") :prefilter)
                        (= (or (and parsed (. parsed :token-key)) "") :lazy)
                        (= (or (and parsed (. parsed :token-key)) "") :escape))
        matches? (not (= parsed nil))]
    (if (or escaped-prefix? (not matches?))
        nil
        {:hash-hl (if off? "MetaPromptFlagHashOff" "MetaPromptFlagHashOn")
         :text-hl (if functional?
                      (if off? "MetaPromptFlagTextFuncOff" "MetaPromptFlagTextFuncOn")
                      (if off? "MetaPromptFlagTextOff" "MetaPromptFlagTextOn"))})))

(fn prompt-line-primary-group
  [row]
  (.. "MetaPromptText" (tostring (+ (% (math.max 0 (- row 1)) 6) 1))))

(fn prompt-tokens
  [txt]
  ((or (. query-mod :tokenize-line)
       (fn [s] (vim.split s "%s+" {:trimempty true})))
   txt))

(fn directive-arg-style
  [option-prefix tok]
  (let [token (or tok "")
        parsed (directive-mod.parse-token (option-prefix) token)
        await (and parsed (. parsed :await))]
    (if (= (or (and await (. await :kind)) "") "query-source")
        {:text-hl "MetaPromptLgrep"}
        nil)))

(fn inline-file-filter-style
  [option-prefix tok]
  (let [token (or tok "")
        colon (string.find token ":" 1 true)
        prefix (option-prefix)]
    (when colon
      (let [flag-token (string.sub token 1 (- colon 1))
            parsed (directive-mod.parse-token prefix flag-token)
            style (and parsed (control-token-style option-prefix flag-token))]
        (when (= (or (and parsed (. parsed :token-key)) "") :include-files)
          {:flag-style style
           :arg-start colon
           :arg-hl "MetaPromptFileArg"})))))

(fn M.highlight-like-line!
  [buf ns row txt primary-hl option-prefix]
  (let [tokens (prompt-tokens txt)]
    (var pos 1)
    (var await-style nil)
    (each [_ token (ipairs tokens)]
      (let [[s e] [(string.find txt token pos true)]]
        (when (and s e)
          (let [s0 (- s 1)
                e0 e]
            (vim.api.nvim_buf_add_highlight buf ns primary-hl row s0 e0)
            (when await-style
              (vim.api.nvim_buf_add_highlight
                buf
                ns
                (or (. await-style :text-hl) "MetaPromptLgrep")
                row
                s0
                e0))
            (if-let [inline-style (inline-file-filter-style option-prefix token)]
              (let [flag-style (. inline-style :flag-style)
                    arg-start (+ s0 (or (. inline-style :arg-start) 0))]
                (when flag-style
                  (vim.api.nvim_buf_add_highlight
                    buf
                    ns
                    (or (. flag-style :hash-hl) primary-hl)
                    row
                    s0
                    (+ s0 1))
                  (when (> arg-start (+ s0 1))
                    (vim.api.nvim_buf_add_highlight
                      buf
                      ns
                      (or (. flag-style :text-hl) primary-hl)
                      row
                      (+ s0 1)
                      arg-start)))
                (when (> e0 arg-start)
                  (vim.api.nvim_buf_add_highlight
                    buf
                    ns
                    (or (. inline-style :arg-hl) "MetaPromptFileArg")
                    row
                    arg-start
                    e0)))
              (when-let [style (control-token-style option-prefix token)]
                (vim.api.nvim_buf_add_highlight
                  buf
                  ns
                  (or (. style :hash-hl) primary-hl)
                  row
                  s0
                  (+ s0 1))
                (when (> e0 (+ s0 1))
                  (vim.api.nvim_buf_add_highlight
                    buf
                    ns
                    (or (. style :text-hl) primary-hl)
                    row
                    (+ s0 1)
                    e0))))
            (set await-style (directive-arg-style option-prefix token))
            (when (and (> (# token) 1) (= (string.sub token 1 1) "!"))
              (vim.api.nvim_buf_add_highlight buf ns "MetaPromptNeg" row s0 e0))
            (let [core (if (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                           (string.sub token 2)
                           token)]
              (when (and (> (# core) 0)
                         (not= nil (string.find core "[\\%[%]%(%)%+%*%?%|]")))
                (vim.api.nvim_buf_add_highlight buf ns "MetaPromptRegex" row s0 e0)))
            (when (and (> (# token) 0) (= (string.sub token 1 1) "^"))
              (vim.api.nvim_buf_add_highlight buf ns "MetaPromptAnchor" row s0 (+ s0 1)))
            (when (and (> (# token) 0) (= (string.sub token (# token)) "$"))
              (vim.api.nvim_buf_add_highlight buf ns "MetaPromptAnchor" row (- e0 1) e0))
            (set pos (+ e 1))))))))

(fn render-project-flags-footer!
  [session session-prompt-valid? schedule-loading-indicator!]
  (when (and session.prompt-buf
             (session-prompt-valid? session))
    (let [ns (or session.prompt-footer-ns
                 (vim.api.nvim_create_namespace "metabuffer.prompt.footer"))]
      (set session.prompt-footer-ns ns)
      (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
      (schedule-loading-indicator! session))))

(fn M.refresh-highlights!
  [session opts]
  "Refresh prompt token highlighting and footer state for SESSION."
  (let [{: option-prefix : session-prompt-valid? : schedule-loading-indicator!} (or opts {})]
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (let [ns (or session.prompt-hl-ns
                   (vim.api.nvim_create_namespace "metabuffer.prompt"))
            lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
        (set session.prompt-hl-ns ns)
        (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
        (each [row line (ipairs (or lines []))]
          (let [r (- row 1)
                txt (or line "")
                primary-hl (prompt-line-primary-group row)]
            (M.highlight-like-line! session.prompt-buf ns r txt primary-hl option-prefix)))
        (render-project-flags-footer! session session-prompt-valid? schedule-loading-indicator!)))))

M
