(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local directive-mod (require :metabuffer.query.directive))
(local query-mod (require :metabuffer.query))
(local M {})

(fn M.new
  [opts]
  "Build prompt-buffer rendering helpers.

   Returns a helper map for prompt token highlighting and full-buffer refresh."
  (let [{: option-prefix : session-prompt-valid? : schedule-loading-indicator!} opts]
    (fn control-token-style
      [tok]
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
      [tok]
      (let [token (or tok "")
            prefix (option-prefix)
            parsed (directive-mod.parse-token prefix token)
            await (and parsed (. parsed :await))]
        (if (= (or (and await (. await :kind)) "") "query-source")
            {:text-hl "MetaPromptLgrep"}
            nil)))

    (fn inline-file-filter-style
      [tok]
      (let [token (or tok "")
            colon (string.find token ":" 1 true)
            prefix (option-prefix)]
        (when colon
          (let [flag-token (string.sub token 1 (- colon 1))
                parsed (directive-mod.parse-token prefix flag-token)
                style (and parsed (control-token-style flag-token))]
            (when (= (or (and parsed (. parsed :token-key)) "") :include-files)
              {:flag-style style
               :arg-start colon
               :arg-hl "MetaPromptFileArg"})))))

    (fn highlight-like-line!
      [buf ns row txt primary-hl]
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
                (if-let [inline-style (inline-file-filter-style token)]
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
                  (when-let [style (control-token-style token)]
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
                (set await-style (directive-arg-style token))
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
      [session]
      (when (and session.prompt-buf
                 (session-prompt-valid? session))
        (let [ns (or session.prompt-footer-ns
                     (vim.api.nvim_create_namespace "metabuffer.prompt.footer"))]
          (set session.prompt-footer-ns ns)
          (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
          (schedule-loading-indicator! session))))

    (fn refresh-highlights!
      [session]
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
              (highlight-like-line! session.prompt-buf ns r txt primary-hl)))
          (render-project-flags-footer! session))))

    {:highlight-like-line! highlight-like-line!
     :refresh-highlights! refresh-highlights!}))

M
