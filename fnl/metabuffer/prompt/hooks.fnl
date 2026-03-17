(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local animation-mod (require :metabuffer.window.animation))

(fn M.new
  [opts]
  "Public API: M.new."
  (let [{: mark-prompt-buffer! : default-prompt-keymaps : active-by-prompt
         : default-main-keymaps
         : on-prompt-changed : update-info-window : maybe-sync-from-main!
         : schedule-scroll-sync! : maybe-restore-hidden-ui!
         : maybe-refresh-preview-statusline! : sign-mod} opts]
    (let [animation-enabled? (. animation-mod :enabled?)
          animation-duration-ms (. animation-mod :duration-ms)]
    (fn prompt-animation-delay-ms
      [session]
      (if (and animation-mod
               animation-enabled?
               (animation-enabled? session :prompt))
          (animation-duration-ms session :prompt 140)
          0))

    (fn disable-cmp
  [session]
      (mark-prompt-buffer! session.prompt-buf)
      (let [[ok cmp] [(pcall require :cmp)]]
        (when ok
          (pcall cmp.setup.buffer {:enabled false})
          (pcall cmp.abort))))

    (fn switch-mode
  [session which]
      (let [meta session.meta]
        (meta.switch_mode which)
        (pcall meta.refresh_statusline)))

    (fn session-prompt-valid?
  [session]
      (and session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)))

    (fn schedule-when-valid
  [session f]
      (vim.schedule
        (fn []
          (when (session-prompt-valid? session)
            (f)))))

    (fn option-prefix
      []
      (let [p (. vim.g "meta#prefix")]
        (if (and (= (type p) "string") (~= p ""))
            p
            "#")))

    (fn some=
      [needle coll]
      (let [hit0 false]
        (var hit hit0)
        (each [_ item (ipairs (or coll []))]
          (when (= needle item)
            (set hit true)))
        hit))

    (fn control-token-style
      [tok]
      (let [token (or tok "")
            prefix (option-prefix)
            escaped-prefix? (and (vim.startswith token "\\")
                                 (vim.startswith (string.sub token 2) prefix))
            sign (string.match token "^#([%+%-])")
            base (if sign
                     (string.sub token 3)
                     (if (vim.startswith token "#")
                         (string.sub token 2)
                         (if (and (~= prefix "#") (vim.startswith token prefix))
                             (string.sub token (+ (# prefix) 1))
                             "")))
            toggle-off? (some= base
                               ["nohidden" "noignored" "nodeps" "nobinary" "nohex"
                                "nofile" "noprefilter" "nolazy" "escape"])
            toggle-on? (some= base
                              ["hidden" "ignored" "deps" "binary" "hex" "file"
                               "prefilter" "lazy"])
            functional? (some= base ["hex" "nohex" "prefilter" "noprefilter" "lazy" "nolazy" "escape"])
            off? (or (= sign "-") toggle-off?)]
        (if (or escaped-prefix? (= base ""))
            nil
            (if (or (= sign "+") (= sign "-") toggle-on? toggle-off?)
                {:hash-hl (if off? "MetaPromptFlagHashOff" "MetaPromptFlagHashOn")
                 :text-hl (if functional?
                              (if off? "MetaPromptFlagTextFuncOff" "MetaPromptFlagTextFuncOn")
                              (if off? "MetaPromptFlagTextOff" "MetaPromptFlagTextOn"))}
                nil))))

    (fn project-flag-token
      [name on?]
      [(if on?
           (.. "#" name)
           (.. "#-" name))
       (control-token-style (if on? (.. "#" name) (.. "#-" name)))])

    (fn wrap-flag-pieces
      [pieces max-cols]
      (let [width (math.max 12 (or max-cols 12))
            lines []
            current0 {}
            line-w0 0]
        (var current current0)
        (var line-w line-w0)
        (fn flush-line!
          []
          (when (> (# current) 0)
            (table.insert lines current)
            (set current {})
            (set line-w 0)))
        (each [_ p (ipairs pieces)]
          (let [chunks (or (. p :chunks) [[(or (. p :text) "") (or (. p :hl) "MetaPromptText")]])
                w (or (. p :width)
                      (let [sum0 0]
                        (var sum sum0)
                        (each [_ c (ipairs chunks)]
                          (set sum (+ sum (vim.fn.strdisplaywidth (or (. c 1) "")))))
                        sum))]
            (if (and (> line-w 0) (> (+ line-w w) width))
                (flush-line!))
            (each [_ c (ipairs chunks)]
              (table.insert current [(or (. c 1) "") (or (. c 2) "MetaPromptText")]))
            (set line-w (+ line-w w))))
        (flush-line!)
        (if (> (# lines) 0) lines [[["" "MetaPromptText"]]])))

    (fn line-display-rows
      [line width]
      (let [w (math.max 1 (or width 1))
            n (vim.fn.strdisplaywidth (or line ""))]
        (math.max 1 (math.ceil (/ n w)))))

    (fn session-busy?
      [session]
      (and session
           (or session.prompt-update-pending
               session.prompt-update-dirty
               session.lazy-refresh-pending
               session.lazy-refresh-dirty
               session.project-bootstrap-pending
               (and session.project-mode
                    (not session.project-bootstrapped)))))

    (var refresh-prompt-highlights! nil)

    (fn loading-pieces
      [session]
      (let [word "Working"
            phase (or session.loading-anim-phase 0)
            pieces []
            center (+ 1 (% phase (# word)))]
        (for [i 1 (# word)]
          (let [dist (math.abs (- i center))
                hl (if (= dist 0)
                       "MetaLoading6"
                       (= dist 1)
                       "MetaLoading5"
                       (= dist 2)
                       "MetaLoading4"
                       (= dist 3)
                       "MetaLoading3"
                       (= dist 4)
                       "MetaLoading2"
                       "MetaLoading1")]
            (table.insert pieces [(string.sub word i i) hl])))
        [{:chunks pieces :width (# word)}]))

    (fn schedule-loading-indicator!
      [session]
      (when (and session
                 (not session.loading-anim-pending)
                 session.prompt-buf
                 (session-prompt-valid? session)
                 session.loading-indicator?
                 (session-busy? session))
        (set session.loading-anim-pending true)
        (vim.defer_fn
          (fn []
            (set session.loading-anim-pending false)
            (when (and (session-prompt-valid? session)
                       (session-busy? session)
                       animation-enabled?
                       (animation-enabled? session :loading))
              (set session.loading-anim-phase (+ 1 (or session.loading-anim-phase 0)))
              (refresh-prompt-highlights! session)))
          (animation-duration-ms session :loading 90))))

    (fn prompt-content-display-rows
      [session width]
      (let [rows0 0]
        (var rows rows0)
        (each [_ line (ipairs (or (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false) []))]
          (set rows (+ rows (line-display-rows line width))))
        (math.max 1 rows)))

    (fn render-project-flags-footer!
      [session]
      (when (and session.prompt-buf
                 (session-prompt-valid? session))
        (let [ns (or session.prompt-footer-ns (vim.api.nvim_create_namespace "metabuffer.prompt.footer"))
              row (math.max 0 (- (vim.api.nvim_buf_line_count session.prompt-buf) 1))
              last-line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf row (+ row 1) false) 1) "")
              [hidden-token hidden-style] (project-flag-token "hidden" (not (not session.effective-include-hidden)))
              [ignored-token ignored-style] (project-flag-token "ignored" (not (not session.effective-include-ignored)))
              [deps-token deps-style] (project-flag-token "deps" (not (not session.effective-include-deps)))
              [file-token file-style] (project-flag-token "file" (not (not session.effective-include-files)))
              [binary-token binary-style] (project-flag-token "binary" (not (not session.effective-include-binary)))
              [hex-token hex-style] (project-flag-token "hex" (not (not session.effective-include-hex)))
              [prefilter-token prefilter-style] (project-flag-token "prefilter" (not (not session.prefilter-mode)))
              [lazy-token lazy-style] (project-flag-token "lazy" (not (not session.lazy-mode)))
              tokens [[hidden-token hidden-style]
                      [ignored-token ignored-style]
                      [deps-token deps-style]
                      [file-token file-style]
                      [binary-token binary-style]
                      [hex-token hex-style]
                      [prefilter-token prefilter-style]
                      [lazy-token lazy-style]]
              loading0 (if (session-busy? session) (loading-pieces session) [])
              pieces0 []
              _ (each [_ p (ipairs loading0)]
                  (table.insert pieces0 p))
              _ (when (> (# loading0) 0)
                  (table.insert pieces0 {:chunks [["  " "MetaPromptText"]] :width 2}))
              _ (each [i pair (ipairs tokens)]
                  (let [tok (or (. pair 1) "")
                        style (. pair 2)
                        sign-hl (or (and style (. style :hash-hl)) "MetaPromptText")
                        text-hl (or (and style (. style :text-hl)) "MetaPromptText")]
                    (when (> (# tok) 0)
                      (if (vim.startswith tok "#-")
                          (let [suffix (if (> (# tok) 2) (string.sub tok 3) "")
                                chunks [["-" sign-hl] [suffix text-hl]]
                                w (+ 1 (vim.fn.strdisplaywidth suffix))]
                            (table.insert pieces0 {:chunks chunks :width w}))
                          (if (vim.startswith tok "#")
                              (let [suffix (if (> (# tok) 1) (string.sub tok 2) "")
                                    chunks [["+" sign-hl] [suffix text-hl]]
                                    w (+ 1 (vim.fn.strdisplaywidth suffix))]
                                (table.insert pieces0 {:chunks chunks :width w}))
                              (table.insert pieces0 {:chunks [[tok text-hl]]
                                                     :width (vim.fn.strdisplaywidth tok)}))))
                    (when (< i (# tokens))
                      (table.insert pieces0 {:chunks [[" " "MetaPromptText"]] :width 1}))))
              pieces pieces0
              max-cols (if (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
                           (vim.api.nvim_win_get_width session.prompt-win)
                           80)
              win-height (if (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
                             (vim.api.nvim_win_get_height session.prompt-win)
                             1)
              last-line-rows (line-display-rows last-line max-cols)
              anchor-row (math.max 0 (- row (math.max 0 (- last-line-rows 1))))
              flag-lines (wrap-flag-pieces pieces max-cols)
              content-rows (prompt-content-display-rows session max-cols)
              spacer-count (math.max 0 (- win-height content-rows (# flag-lines)))
              virt-lines0 []
              _ (each [_ _i (ipairs (vim.fn.range 1 spacer-count))]
                  (table.insert virt-lines0 [["" "MetaPromptText"]]))
              _ (each [_ vl (ipairs flag-lines)]
                  (table.insert virt-lines0 vl))
              virt-lines virt-lines0]
          (set session.prompt-footer-ns ns)
          (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
          (when session.project-mode
            (vim.api.nvim_buf_set_extmark
              session.prompt-buf
              ns
              anchor-row
              0
              {:virt_lines virt-lines
               :virt_lines_above false
               :hl_mode "combine"}))
          (schedule-loading-indicator! session))))

    (set refresh-prompt-highlights!
      (fn [session]
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (let [ns (or session.prompt-hl-ns (vim.api.nvim_create_namespace "metabuffer.prompt"))
              lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
          (set session.prompt-hl-ns ns)
          (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
          (each [row line (ipairs (or lines []))]
            (let [r (- row 1)
                  txt (or line "")]
              (var pos 1)
              (while (<= pos (# txt))
                (let [[s e] [(string.find txt "%S+" pos)]]
                  (if (and s e)
                      (let [token (string.sub txt s e)
                            s0 (- s 1)
                            e0 e]
                        (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptText" r s0 e0)
                        (when-let [style (control-token-style token)]
                          (vim.api.nvim_buf_add_highlight
                            session.prompt-buf
                            ns
                            (or (. style :hash-hl) "MetaPromptText")
                            r
                            s0
                            (+ s0 1))
                          (when (> e0 (+ s0 1))
                            (vim.api.nvim_buf_add_highlight
                              session.prompt-buf
                              ns
                              (or (. style :text-hl) "MetaPromptText")
                              r
                              (+ s0 1)
                              e0)))
                        (when (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptNeg" r s0 e0))
                        (let [core (if (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                                        (string.sub token 2)
                                        token)]
                          (when (and (> (# core) 0)
                                     (not (not (string.find core "[\\%[%]%(%)%+%*%?%|]"))))
                            (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptRegex" r s0 e0)))
                        (when (and (> (# token) 0) (= (string.sub token 1 1) "^"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r s0 (+ s0 1)))
                        (when (and (> (# token) 0) (= (string.sub token (# token)) "$"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r (- e0 1) e0))
                        (set pos (+ e 1)))
                        (set pos (+ (# txt) 1)))))))
          (render-project-flags-footer! session)))))

    (fn maybe-expand-history-shorthand!
  [router session]
      (if session._expanding-history-shorthand
          false
          (if (and session
                   session.prompt-buf
                   session.prompt-win
                   (vim.api.nvim_buf_is_valid session.prompt-buf)
                   (vim.api.nvim_win_is_valid session.prompt-win))
              (let [[row col] (vim.api.nvim_win_get_cursor session.prompt-win)
                    row0 (math.max 0 (- row 1))
                    line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf row0 (+ row0 1) false) 1) "")
                    left (if (> col 0) (string.sub line 1 col) "")
                    saved-tag (string.match left "##([%w_%-]+)$")
                    saved-replacement (if saved-tag
                                          (router.saved-prompt-entry saved-tag)
                                          "")
                    trigger (if (and (>= col 3) (vim.endswith left "!^!"))
                                "!^!"
                                (and (>= col 2) (vim.endswith left "!!"))
                                "!!"
                                (and (>= col 2) (vim.endswith left "!$"))
                                "!$"
                                nil)
                    replacement (if (= trigger "!!")
                                    (router.last-prompt-entry session.prompt-buf)
                                    (= trigger "!$")
                                    (router.last-prompt-token session.prompt-buf)
                                    (= trigger "!^!")
                                    (router.last-prompt-tail session.prompt-buf)
                                    "")]
                (if (and trigger (= (type replacement) "string") (~= replacement ""))
                    (do
                      (set session._expanding-history-shorthand true)
                      (let [start-col (- col (if (= trigger "!^!") 3 2))]
                        (vim.api.nvim_buf_set_text session.prompt-buf row0 start-col row0 col [""])
                        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row start-col]))
                      (if (= trigger "!!")
                          (router.insert-last-prompt session.prompt-buf)
                          (= trigger "!$")
                          (router.insert-last-token session.prompt-buf)
                          (router.insert-last-tail session.prompt-buf))
                      (set session._expanding-history-shorthand false)
                      true)
                    (if (and saved-tag
                             (= (type saved-replacement) "string")
                             (~= saved-replacement ""))
                        (do
                          (set session._expanding-history-shorthand true)
                          (let [tag-len (+ 2 (# saved-tag))
                                start-col (- col tag-len)]
                            (vim.api.nvim_buf_set_text session.prompt-buf row0 start-col row0 col [""])
                            (pcall vim.api.nvim_win_set_cursor session.prompt-win [row start-col]))
                          (router.prompt-insert-text session.prompt-buf saved-replacement)
                          (set session._expanding-history-shorthand false)
                          true)
                        false)))
              false)))

    (fn resolve-map-action
  [router session action arg]
      (if
        (= action "accept")
        (fn [] (router.accept session.prompt-buf))
        (= action "enter-edit-mode")
        (fn [] (router.enter-edit-mode session.prompt-buf))
        (= action "cancel")
        (fn [] (router.cancel session.prompt-buf))
        (= action "move-selection")
        (fn [] (router.move-selection session.prompt-buf arg))
        (= action "history-or-move")
        (fn [] (router.history-or-move session.prompt-buf arg))
        (= action "prompt-home")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-home session.prompt-buf))))
        (= action "prompt-end")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-end session.prompt-buf))))
        (= action "prompt-kill-backward")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-kill-backward session.prompt-buf))))
        (= action "prompt-kill-forward")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-kill-forward session.prompt-buf))))
        (= action "prompt-yank")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-yank session.prompt-buf))))
        (= action "insert-last-prompt")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-prompt session.prompt-buf))))
        (= action "insert-last-token")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-token session.prompt-buf))))
        (= action "insert-last-tail")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-tail session.prompt-buf))))
        (= action "toggle-prompt-results-focus")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.toggle-prompt-results-focus session.prompt-buf))))
        (= action "negate-current-token")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.negate-current-token session.prompt-buf))))
        (= action "history-searchback")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.open-history-searchback session.prompt-buf))))
        (= action "merge-history")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.merge-history-cache session.prompt-buf))))
        (= action "switch-mode")
        (fn [] (switch-mode session arg))
        (= action "toggle-scan-option")
        (fn [] (router.toggle-scan-option session.prompt-buf arg))
        (= action "scroll-main")
        (fn [] (router.scroll-main session.prompt-buf arg))
        (= action "toggle-project-mode")
        (fn [] (router.toggle-project-mode session.prompt-buf))
        (= action "toggle-info-file-entry-view")
        (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
        nil))

    (fn apply-keymaps
      [router session]
      (let [base-opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}
            rules (or session.prompt-keymaps default-prompt-keymaps)]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                opts (if (or (= action "insert-last-prompt")
                             (= action "insert-last-token")
                             (= action "insert-last-tail"))
                         (vim.tbl_extend "force" base-opts {:nowait false})
                         base-opts)
                rhs (resolve-map-action router session action arg)]
            (if rhs
                (vim.keymap.set mode lhs rhs opts)
                (vim.notify
                  (.. "metabuffer: unknown prompt keymap action '" (tostring action) "' for " (tostring lhs))
                  vim.log.levels.WARN))))))

    (fn apply-emacs-insert-fallbacks
  [router session]
      (let [base-opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}
            rules (or session.prompt-fallback-keymaps [])]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                rhs (resolve-map-action router session action arg)]
            (when rhs
              (vim.keymap.set mode lhs rhs base-opts))))))

    (fn resolve-main-map-action
      [router session action arg]
      (if
        (= action "accept-main")
        (fn [] (router.accept-main session.prompt-buf))
        (= action "enter-edit-mode")
        (fn [] (router.enter-edit-mode session.prompt-buf))
        (= action "exclude-symbol-under-cursor")
        (fn [] (router.exclude-symbol-under-cursor session.prompt-buf))
        (= action "insert-symbol-under-cursor")
        (fn [] (router.insert-symbol-under-cursor session.prompt-buf))
        (= action "insert-symbol-under-cursor-newline")
        (fn [] (router.insert-symbol-under-cursor-newline session.prompt-buf))
        (= action "toggle-prompt-results-focus")
        (fn [] (router.toggle-prompt-results-focus session.prompt-buf))
        (= action "scroll-main")
        (fn [] (router.scroll-main session.prompt-buf arg))
        (= action "toggle-info-file-entry-view")
        (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
        nil))

    (fn apply-main-keymaps
      [router session]
      (let [base-opts {:buffer session.meta.buf.buffer :silent true :noremap true :nowait true}
            rules (or session.main-keymaps default-main-keymaps)]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                rhs (resolve-main-map-action router session action arg)]
            (if rhs
                (vim.keymap.set mode lhs rhs base-opts)
                (vim.notify
                  (.. "metabuffer: unknown main keymap action '" (tostring action) "' for " (tostring lhs))
                  vim.log.levels.WARN))))))

    (fn register!
  [router session]
      (let [aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true})]
        (set session.augroup aug)
      ;; Some environments/plugins do not reliably emit TextChangedI for this
      ;; scratch prompt buffer; keep a low-level line-change hook as a fallback.
        (vim.api.nvim_buf_attach session.prompt-buf false
          {:on_lines (fn [_ _ changedtick _ _ _ _ _]
                       ;; on_lines can fire before insert-state buffer text is fully
                       ;; visible; defer one tick so we observe the committed prompt.
                       (vim.schedule
                         (fn []
                           (when (and session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (if (maybe-expand-history-shorthand! router session)
                                 nil
                                 (do
                                   (refresh-prompt-highlights! session)
                                   (on-prompt-changed session.prompt-buf false changedtick)))))))
           :on_detach (fn []
                        (when session.prompt-buf
                          (set (. active-by-prompt session.prompt-buf) nil)))})
      ;; Prompt text updates: rely on post-change autocmds to avoid pre-edit race
      ;; behavior that can leave matcher one character behind while typing.
        (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (if (maybe-expand-history-shorthand! router session)
                           nil
                           (do
                             (refresh-prompt-highlights! session)
                             (on-prompt-changed
                               session.prompt-buf
                               false
                               (vim.api.nvim_buf_get_changedtick session.prompt-buf)))))})
      ;; Re-assert prompt maps when entering insert mode; this wins over late
      ;; plugin mappings (for example completion plugins).
        (vim.api.nvim_create_autocmd "InsertEnter"
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid
                         session
                         (fn []
                           (disable-cmp session)
                           (apply-keymaps router session)
                           (apply-emacs-insert-fallbacks router session))))})
      ;; Some statusline plugins or focus transitions (for example tmux pane
      ;; switches) can overwrite local statusline state. Re-apply ours when the
      ;; prompt window regains focus.
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (pcall session.meta.refresh_statusline))))})
      ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
        (vim.api.nvim_create_autocmd ["ModeChanged" "InsertEnter" "InsertLeave"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (pcall session.meta.refresh_statusline))))})
      (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
        {:group aug
         :buffer session.prompt-buf
         :callback (fn [_]
                     (schedule-when-valid session
                       (fn []
                         (when maybe-refresh-preview-statusline!
                           (pcall maybe-refresh-preview-statusline! session)))))})
      ;; Recompute floating info rendering/width when editor windows resize.
        (vim.api.nvim_create_autocmd ["VimResized" "WinResized"]
          {:group aug
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (when-not session.prompt-animating?
                             (pcall refresh-prompt-highlights! session)
                             (pcall update-info-window session)))))} )
      ;; Keep selection/status/info synced when user scrolls or moves in the
      ;; main meta window with regular motions/mouse while prompt is open.
        (vim.api.nvim_create_autocmd ["CursorMoved" "CursorMovedI"]
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (maybe-sync-from-main! session))))})
        (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (when (and sign-mod session.meta session.meta.buf)
                         (let [buf session.meta.buf.buffer
                               internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                                           (and ok v))]
                           (when-not internal?
                             (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" true))
                           (vim.schedule
                             (fn []
                               (when (and session.prompt-buf
                                          (= (. active-by-prompt session.prompt-buf) session))
                                 (pcall router.sync-live-edits session.prompt-buf)
                                 (pcall maybe-sync-from-main! session true)
                                 (pcall update-info-window session true)
                                 (pcall sign-mod.refresh-change-signs! session)))))))})
        (vim.api.nvim_create_autocmd "BufEnter"
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (when (and session.meta session.meta.buf (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                         (let [bo (. vim.bo session.meta.buf.buffer)]
                           (set (. bo :buftype) "acwrite")
                           (set (. bo :modifiable) true)
                           (set (. bo :readonly) false)
                           (set (. bo :bufhidden) "hide")))
                       (when maybe-restore-hidden-ui!
                         ;; Defer UI restoration until after the jump/BufEnter
                         ;; command stack settles; restoring windows directly
                         ;; inside BufEnter can surface invalid mark jumps.
                         (vim.schedule
                           (fn []
                             (when (and session.prompt-buf
                                        (= (. active-by-prompt session.prompt-buf) session))
                               (pcall maybe-restore-hidden-ui! session))))))})
        (vim.api.nvim_create_autocmd "BufLeave"
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       ;; When leaving the results buffer, check if the window it
                       ;; was in is now showing something else. If so, close Meta.
                       (vim.schedule
                         (fn []
                           (when (and session.prompt-buf
                                      (vim.api.nvim_buf_is_valid session.prompt-buf)
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (let [win session.meta.win.window]
                               (if (not (vim.api.nvim_win_is_valid win))
                                   (router.cancel session.prompt-buf)
                                   (let [buf (vim.api.nvim_win_get_buf win)]
                                     (when (not= buf session.meta.buf.buffer)
                                       (router.cancel session.prompt-buf)))))))))})
        (apply-main-keymaps router session)
        (vim.api.nvim_create_autocmd "WinScrolled"
          {:group aug
           :callback (fn [_]
                       (schedule-scroll-sync! session))})
        (vim.api.nvim_create_autocmd "BufWriteCmd"
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (router.write-results session.prompt-buf))})
        (vim.api.nvim_create_autocmd "BufWipeout"
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (vim.schedule
                         (fn []
                           (router.results-buffer-wiped session.meta.buf.buffer))))})
        (disable-cmp session)
        (mark-prompt-buffer! session.prompt-buf)
        (refresh-prompt-highlights! session)
        ;; Prompt/footer layout can change one tick later after split/floating
        ;; windows settle; rerender so wrapped footer lines are visible at open.
        (vim.defer_fn
          (fn []
            (when (and session.prompt-buf
                       (= (. active-by-prompt session.prompt-buf) session))
              (pcall refresh-prompt-highlights! session)))
          (prompt-animation-delay-ms session))
        (apply-keymaps router session)
        (apply-emacs-insert-fallbacks router session)))

    {:register! register!
     :refresh! refresh-prompt-highlights!})))

M
