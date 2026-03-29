(local directive-mod (require :metabuffer.query.directive))

(local M {})

(fn M.new
  [opts]
  "Build prompt token highlight and directive-help helpers.

   Returns a map of prompt-view helper functions."
  (let [{: option-prefix : highlight-prompt-like-line!} opts]

    (fn current-prompt-token
      [session]
      (when (and session.prompt-win
                 (vim.api.nvim_win_is_valid session.prompt-win)
                 session.prompt-buf
                 (vim.api.nvim_buf_is_valid session.prompt-buf))
        (vim.api.nvim_win_call
          session.prompt-win
          (fn []
            (let [row-col (vim.api.nvim_win_get_cursor 0)
                  row (or (. row-col 1) 1)
                  col1 (+ (or (. row-col 2) 0) 1)
                  line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf (- row 1) row false) 1) "")]
              (let [span (directive-mod.token-under-cursor line col1)]
                (if span
                    (vim.tbl_extend "force" span {:row row})
                    nil)))))))

    (fn directive-help-token
      [tok]
      (let [token (or tok "")
            prefix (option-prefix)
            colon (string.find token ":" 1 true)]
        (if colon
            (let [stem (string.sub token 1 (- colon 1))]
              (if (directive-mod.parse-token prefix stem)
                  stem
                  token))
            token)))

    (fn directive-help-spec-for-token
      [token]
      (let [needle (or token "")
            prefix (option-prefix)
            matches (directive-mod.matching-catalog prefix needle)]
        (var exact nil)
        (each [_ spec (ipairs matches)]
          (when (and (not exact)
                     (or (= (or (. spec :display) "") needle)
                         (= (or (. spec :literal) "") needle)
                         (= (or (. spec :prefix) "") needle)))
            (set exact spec)))
        (or exact (. matches 1))))

    (fn hide-directive-help!
      [session]
      (when (and session.directive-help-win
                 (vim.api.nvim_win_is_valid session.directive-help-win))
        (pcall vim.api.nvim_win_close session.directive-help-win true))
      (set session.directive-help-win nil)
      (when (and session.directive-help-buf
                 (not (vim.api.nvim_buf_is_valid session.directive-help-buf)))
        (set session.directive-help-buf nil)))

    (fn show-directive-help!
      [session spec span]
      (when (and session.prompt-win
                 (vim.api.nvim_win_is_valid session.prompt-win)
                 spec)
        (let [buf0 (and session.directive-help-buf
                        (vim.api.nvim_buf_is_valid session.directive-help-buf)
                        session.directive-help-buf)
              buf (or buf0 (vim.api.nvim_create_buf false true))
              _ (set session.directive-help-buf buf)
              help (or (. spec :help) "")
              display (if (= (or (. spec :token-key) "") :include-files)
                          (.. (option-prefix) "file:{filter}")
                          (or (. spec :display) ""))
              lines [display help]
              width (math.max (# display) (# help) 12)
              row1 (or (and span (. span :row)) 1)
              col1 (or (and span (. span :start)) 1)
              screenpos (vim.fn.screenpos session.prompt-win row1 col1)
              screen-row (math.max 1 (or (. screenpos :row) 1))
              screen-col (math.max 1 (or (. screenpos :col) 1))
              cfg {:relative "editor"
                   :row (math.max 0 (- screen-row (+ (# lines) 3)))
                   :col (math.max 0 (- screen-col 1))
                   :width width
                   :height (# lines)
                   :style "minimal"
                   :border "rounded"
                   :focusable false
                   :noautocmd true}]
          (let [bo (. vim.bo buf)]
            (set (. bo :buftype) "nofile")
            (set (. bo :bufhidden) "wipe")
            (set (. bo :swapfile) false)
            (set (. bo :modifiable) true))
          (pcall vim.api.nvim_buf_set_name buf "[Metabuffer Directive Help]")
          (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
          (let [ns (or session.directive-help-hl-ns
                       (vim.api.nvim_create_namespace "metabuffer.directive-help"))]
            (set session.directive-help-hl-ns ns)
            (vim.api.nvim_buf_clear_namespace buf ns 0 -1)
            (highlight-prompt-like-line! buf ns 0 display "MetaPromptText1")
            (vim.api.nvim_buf_add_highlight buf ns "Comment" 1 0 -1))
          (let [bo (. vim.bo buf)]
            (set (. bo :modifiable) false))
          (if (and session.directive-help-win
                   (vim.api.nvim_win_is_valid session.directive-help-win))
              (do
                (pcall vim.api.nvim_win_set_buf session.directive-help-win buf)
                (pcall vim.api.nvim_win_set_config session.directive-help-win cfg))
              (set session.directive-help-win (vim.api.nvim_open_win buf false cfg))))))

    (fn maybe-show-directive-help!
      [session selected-item]
      (if (or (not session.prompt-win)
              (not (vim.api.nvim_win_is_valid session.prompt-win))
              (~= (vim.api.nvim_get_current_win) session.prompt-win))
          (hide-directive-help! session)
          (let [span (current-prompt-token session)]
            (if span
                (let [selected-word (or (and selected-item (. selected-item :word))
                                        (and selected-item (. selected-item :abbr))
                                        "")
                      token (directive-help-token (or (. span :token) ""))
                      prefix (option-prefix)
                      spec (if (and (~= selected-word "")
                                    (vim.startswith selected-word prefix))
                               (directive-help-spec-for-token selected-word)
                               (and (vim.startswith token prefix)
                                    (directive-help-spec-for-token token)))]
                  (if spec
                      (show-directive-help! session spec span)
                      (hide-directive-help! session)))
                (hide-directive-help! session)))))

    (fn maybe-trigger-directive-complete!
      [session]
      (when (and session.prompt-win
                 (vim.api.nvim_win_is_valid session.prompt-win)
                 (= (vim.api.nvim_get_current_win) session.prompt-win)
                 (vim.startswith (or (. (vim.api.nvim_get_mode) :mode) "") "i"))
        (let [span (current-prompt-token session)]
          (if span
              (let [token (or (. span :token) "")
                    prefix (option-prefix)
                    matches (if (vim.startswith token prefix)
                                (directive-mod.complete-items prefix token)
                                [])
                    start (or (. span :start) 1)]
                (when (and (> (# matches) 0)
                           (= 0 (vim.fn.pumvisible))
                           (~= token (or session.directive-last-complete-token "")))
                  (set session.directive-last-complete-token token)
                  (vim.fn.complete start matches)))
              (set session.directive-last-complete-token nil)))))

    {:current-prompt-token current-prompt-token
     :hide-directive-help! hide-directive-help!
     :maybe-show-directive-help! maybe-show-directive-help!
     :maybe-trigger-directive-complete! maybe-trigger-directive-complete!}))

M
