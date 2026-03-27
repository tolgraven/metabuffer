(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local animation-mod (require :metabuffer.window.animation))
(local events (require :metabuffer.events))
(local query-mod (require :metabuffer.query))
(local directive-mod (require :metabuffer.query.directive))

(fn M.new
  [opts]
  "Public API: M.new."
    (let [{: default-prompt-keymaps : active-by-prompt
         : default-main-keymaps
         : on-prompt-changed : update-info-window : update-preview-window
         : maybe-sync-from-main!
         : schedule-scroll-sync! : maybe-restore-hidden-ui!
         : hide-visible-ui!
         : rebuild-source-set!
         : maybe-refresh-preview-statusline!
         : maybe-refresh-info-statusline!
         : sign-mod} opts]
    (let [animation-enabled? (. animation-mod :enabled?)
          animation-duration-ms (. animation-mod :duration-ms)]
    (fn prompt-animation-delay-ms
      [session]
      (if (and animation-mod
               animation-enabled?
               (animation-enabled? session :prompt))
          (animation-duration-ms session :prompt 140)
          0))

    (fn switch-mode
  [session which]
      (let [meta session.meta]
        (meta.switch_mode which)
        (pcall meta.refresh_statusline)))

    (fn nvim-exiting?
      []
      (let [v (and vim.v (. vim.v :exiting))]
        (and (~= v nil)
             (~= v vim.NIL)
             (~= v 0)
             (~= v ""))))

    (fn session-prompt-valid?
  [session]
      (and (not (nvim-exiting?))
           session
           (not session.ui-hidden)
           (not session.closing)
           session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)
           (= (. active-by-prompt session.prompt-buf) session)))

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

    (fn window-rect
      [win]
      (when (and win (= (type win) "number") (vim.api.nvim_win_is_valid win))
        (let [pos (vim.api.nvim_win_get_position win)
              row (or (. pos 1) 0)
              col (or (. pos 2) 0)
              height (vim.api.nvim_win_get_height win)
              width (vim.api.nvim_win_get_width win)]
          {:top row
           :left col
           :bottom (+ row height -1)
           :right (+ col width -1)})))

    (fn rect-overlap?
      [a b]
      (and a b
           (<= (. a :top) (. b :bottom))
           (<= (. b :top) (. a :bottom))
           (<= (. a :left) (. b :right))
           (<= (. b :left) (. a :right))))

    (fn meta-owned-window?
      [session win]
      (let [meta-win (and session.meta session.meta.win session.meta.win.window)
            prompt-win session.prompt-win
            info-win session.info-win
            preview-win session.preview-win
            history-win session.history-browser-win]
        (or (= win meta-win)
            (= win prompt-win)
            (= win info-win)
            (= win preview-win)
            (= win history-win))))

    (fn covered-by-new-window?
      [session win]
      (let [target (window-rect win)
            prompt-win session.prompt-win
            info-win session.info-win
            preview-win session.preview-win
            history-win session.history-browser-win]
        (and target
             (not (meta-owned-window? session win))
             (or (rect-overlap? target (window-rect info-win))
                 (rect-overlap? target (window-rect preview-win))
                 (rect-overlap? target (window-rect history-win))
                 (and session.prompt-floating?
                      (rect-overlap? target (window-rect prompt-win)))))))

    (fn transient-overlay-buffer?
      [buf]
      (when (and buf (= (type buf) "number") (vim.api.nvim_buf_is_valid buf))
        (let [bo (. vim.bo buf)
              ft (or (. bo :filetype) "")
              bt (or (. bo :buftype) "")]
          (or (= ft "help")
              (= ft "man")
              (= bt "help")))))

    (fn first-window-for-buffer
      [buf]
      (when (and buf (= (type buf) "number") (vim.api.nvim_buf_is_valid buf))
        (let [wins (vim.fn.win_findbuf buf)]
          (var found nil)
          (each [_ win (ipairs (or wins []))]
            (when (and (not found) (vim.api.nvim_win_is_valid win))
              (set found win)))
          found)))

    (fn hidden-session-reachable?
      [session]
      (let [results-buf (and session session.meta session.meta.buf session.meta.buf.buffer)]
        (if (not (and results-buf (vim.api.nvim_buf_is_valid results-buf)))
            false
            (if (= (vim.api.nvim_get_current_buf) results-buf)
                true
                (let [raw (vim.fn.getjumplist)
                      jumps (if (and (= (type raw) "table") (= (type (. raw 1)) "table"))
                                (. raw 1)
                                [])]
                  (let [hit0 false]
                    (var hit hit0)
                    (each [_ item (ipairs (or jumps []))]
                      (when (= (or (. item :bufnr) (. item "bufnr")) results-buf)
                        (set hit true)))
                    hit))))))

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
            matches? (clj.boolean parsed)]
        (if (or escaped-prefix? (not matches?))
            nil
            {:hash-hl (if off? "MetaPromptFlagHashOff" "MetaPromptFlagHashOn")
             :text-hl (if functional?
                          (if off? "MetaPromptFlagTextFuncOff" "MetaPromptFlagTextFuncOn")
                          (if off? "MetaPromptFlagTextOff" "MetaPromptFlagTextOn"))})))

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

    (fn session-actually-idle?
      [session]
      (and session
           (not (session-busy? session))
           (not session.prompt-update-dirty)
           (not session.lazy-refresh-dirty)))

    (fn hl-rendered-fg
      [hl]
      (if (and hl (. hl :reverse))
          (or (. hl :bg) (. hl :fg))
          (. hl :fg)))

    (fn hl-rendered-bg
      [hl]
      (if (and hl (. hl :reverse))
          (or (. hl :fg) (. hl :bg))
          (. hl :bg)))

    (fn darken-rgb
      [n factor]
      (if (not n)
          nil
          (let [r (math.floor (/ n 0x10000))
                g (math.floor (% (/ n 0x100) 0x100))
                b (% n 0x100)
                f (math.max 0 (math.min factor 1))
                dr (math.max 0 (math.min 255 (math.floor (* r (- 1 f)))))
                dg (math.max 0 (math.min 255 (math.floor (* g (- 1 f)))))
                db (math.max 0 (math.min 255 (math.floor (* b (- 1 f)))))]
            (+ (* dr 0x10000) (* dg 0x100) db))))

    (fn brighten-rgb
      [n factor]
      (if (not n)
          nil
          (let [r (math.floor (/ n 0x10000))
                g (math.floor (% (/ n 0x100) 0x100))
                b (% n 0x100)
                f (math.max 0 (math.min factor 1))
                br (math.max 0 (math.min 255 (math.floor (+ r (* (- 255 r) f)))))
                bg (math.max 0 (math.min 255 (math.floor (+ g (* (- 255 g) f)))))
                bb (math.max 0 (math.min 255 (math.floor (+ b (* (- 255 b) f)))))]
            (+ (* br 0x10000) (* bg 0x100) bb))))

    (fn results-pulse-bg
      [step]
      (let [[ok-middle middle] [(pcall vim.api.nvim_get_hl 0 {:name "MetaStatuslineMiddle" :link false})]
            [ok-status status] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
            base (or (and ok-middle (= (type middle) "table") (hl-rendered-bg middle))
                     (and ok-status (= (type status) "table") (hl-rendered-bg status))
                     0x2a2a2a)]
        (if (= step 2)
            (or (brighten-rgb base 0.02) base)
            (= step 3)
            (or (brighten-rgb base 0.04) base)
            (= step 4)
            (or (brighten-rgb base 0.06) base)
            (= step 5)
            (or (brighten-rgb base 0.04) base)
            (= step 6)
            (or (brighten-rgb base 0.02) base)
            (= step 7)
            (or (darken-rgb base 0.02) base)
            (= step 8)
            (or (darken-rgb base 0.04) base)
            (= step 9)
            (or (brighten-rgb base 0.06) base)
            (= step 10)
            (or (brighten-rgb base 0.04) base)
            (= step 11)
            (or (darken-rgb base 0.02) base)
            base)))

    (fn pulse-hl-from
      [group bg]
      (let [opts {:default true :reverse false :cterm {:reverse false}}
            [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
        (when (and ok (= (type hl) "table"))
          (when (hl-rendered-fg hl)
            (set (. opts :fg) (hl-rendered-fg hl)))
          (when (. hl :ctermfg)
            (set (. opts :ctermfg) (. hl :ctermfg)))
          (when (. hl :bold)
            (set (. opts :bold) (. hl :bold))))
        (set (. opts :bg) bg)
        opts))

    (fn update-results-loading-pulse-highlights!
      [step]
      (let [bg (results-pulse-bg step)
            hi vim.api.nvim_set_hl]
        (hi 0 "MetaStatuslineMiddlePulse" (pulse-hl-from "MetaStatuslineMiddle" bg))
        (hi 0 "MetaStatuslineIndicatorPulse" (pulse-hl-from "MetaStatuslineIndicator" bg))
        (hi 0 "MetaStatuslineKeyPulse" (pulse-hl-from "MetaStatuslineKey" bg))
        (hi 0 "MetaStatuslineFlagOnPulse" (pulse-hl-from "MetaStatuslineFlagOn" bg))
        (hi 0 "MetaStatuslineFlagOffPulse" (pulse-hl-from "MetaStatuslineFlagOff" bg))))

    (fn set-results-loading-pulse!
      [session]
      (if (and session session.loading-anim-phase)
          (let [step (+ (% (or session.loading-anim-phase 0) 8) 1)]
            (set session.results-statusline-pulse-active? true)
            (update-results-loading-pulse-highlights! step))
          (set session.results-statusline-pulse-active? nil)))

    (var refresh-prompt-highlights! nil)
    (var schedule-loading-indicator! nil)

    (fn loading-indicator-tick!
      [session]
      (set session.loading-anim-pending false)
      (when (session-prompt-valid? session)
        (let [animating? (and (session-busy? session)
                              animation-enabled?
                              (animation-enabled? session :loading))]
          (if animating?
              (do
                (set session.loading-idle-pending false)
                (set session.loading-anim-phase (+ 1 (or session.loading-anim-phase 0)))
                (set-results-loading-pulse! session)
                (pcall session.meta.refresh_statusline)
                (refresh-prompt-highlights! session)
                (schedule-loading-indicator! session))
              (if session.loading-anim-phase
                  (if session.loading-idle-pending
                      (when (session-actually-idle? session)
                        (set session.loading-idle-pending false)
                        (set session.loading-anim-phase nil)
                        (set-results-loading-pulse! session)
                        (pcall session.meta.refresh_statusline))
                      (do
                        (set session.loading-idle-pending true)
                        (schedule-loading-indicator! session)))
                  (do
                    (set session.loading-idle-pending false)
                    (set-results-loading-pulse! session)))))))

    (set schedule-loading-indicator!
      (fn [session]
        (when (and session
                   (not session.loading-anim-pending)
                   session.prompt-buf
                   (session-prompt-valid? session)
                   session.loading-indicator?
                   (or (session-busy? session)
                       session.loading-anim-phase
                       session.loading-idle-pending))
          (when (and (session-busy? session)
                     (= session.loading-anim-phase nil))
            (set session.loading-idle-pending false)
            (set session.loading-anim-phase 0)
            (set-results-loading-pulse! session)
            (pcall session.meta.refresh_statusline))
          (set session.loading-anim-pending true)
          (let [delay (if session.loading-idle-pending
                          120
                          (animation-duration-ms session :loading 90))]
            (vim.defer_fn
              (fn [] (loading-indicator-tick! session))
              delay)))))

    (fn render-project-flags-footer!
      [session]
      (when (and session.prompt-buf
                 (session-prompt-valid? session))
        (let [ns (or session.prompt-footer-ns (vim.api.nvim_create_namespace "metabuffer.prompt.footer"))
              _ (set session.prompt-footer-ns ns)]
          (set session.prompt-footer-ns ns)
          (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
          (schedule-loading-indicator! session))))

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
              (directive-mod.token-under-cursor line col1))))))

    (fn hide-directive-help!
      [session]
      (when (and session.directive-help-win
                 (vim.api.nvim_win_is_valid session.directive-help-win))
        (pcall vim.api.nvim_win_close session.directive-help-win true))
      (set session.directive-help-win nil))

    (fn show-directive-help!
      [session spec]
      (when (and session.prompt-win
                 (vim.api.nvim_win_is_valid session.prompt-win)
                 spec)
        (let [buf (or session.directive-help-buf (vim.api.nvim_create_buf false true))
              _ (set session.directive-help-buf buf)
              help (or (. spec :help) "")
              display (or (. spec :display) "")
              lines [display help]
              width (math.max (# display) (# help) 12)
              host-pos (vim.api.nvim_win_get_position session.prompt-win)
              row (or (. host-pos 1) 0)
              col (or (. host-pos 2) 0)
              cfg {:relative "editor"
                   :row (math.max 0 (- row 3))
                   :col col
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
          (let [bo (. vim.bo buf)]
            (set (. bo :modifiable) false))
          (if (and session.directive-help-win
                   (vim.api.nvim_win_is_valid session.directive-help-win))
              (do
                (pcall vim.api.nvim_win_set_buf session.directive-help-win buf)
                (pcall vim.api.nvim_win_set_config session.directive-help-win cfg))
              (set session.directive-help-win (vim.api.nvim_open_win buf false cfg))))))

    (fn maybe-show-directive-help!
      [session]
      (if-let [span (current-prompt-token session)]
        (let [token (or (. span :token) "")
              prefix (option-prefix)
              matches (if (vim.startswith token prefix)
                        (directive-mod.matching-catalog prefix token)
                        [])]
          (if (> (# matches) 0)
            (show-directive-help! session (. matches 1))
            (hide-directive-help! session)))
        (hide-directive-help! session)))

    (fn maybe-trigger-directive-complete!
      [session]
      (when (and session.prompt-win
                 (vim.api.nvim_win_is_valid session.prompt-win)
                 (= (vim.api.nvim_get_current_win) session.prompt-win)
                 (vim.startswith (or (. (vim.api.nvim_get_mode) :mode) "") "i"))
        (if-let [span (current-prompt-token session)]
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
          (set session.directive-last-complete-token nil))))

    (set refresh-prompt-highlights!
      (fn [session]
        (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
          (let [ns (or session.prompt-hl-ns (vim.api.nvim_create_namespace "metabuffer.prompt"))
                lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
            (set session.prompt-hl-ns ns)
            (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
            (each [row line (ipairs (or lines []))]
                (let [r (- row 1)
                    txt (or line "")
                    primary-hl (prompt-line-primary-group row)
                    tokens (prompt-tokens txt)]
                (var pos 1)
                (var await-style nil)
                (each [_ token (ipairs tokens)]
                  (let [[s e] [(string.find txt token pos true)]]
                    (when (and s e)
                      (let [s0 (- s 1)
                            e0 e]
                        (vim.api.nvim_buf_add_highlight session.prompt-buf ns primary-hl r s0 e0)
                        (when await-style
                          (vim.api.nvim_buf_add_highlight
                            session.prompt-buf
                            ns
                            (or (. await-style :text-hl) "MetaPromptLgrep")
                            r
                            s0
                            e0))
                        (when-let [style (control-token-style token)]
                          (vim.api.nvim_buf_add_highlight
                            session.prompt-buf
                            ns
                            (or (. style :hash-hl) primary-hl)
                            r
                            s0
                            (+ s0 1))
                          (when (> e0 (+ s0 1))
                            (vim.api.nvim_buf_add_highlight
                              session.prompt-buf
                              ns
                              (or (. style :text-hl) primary-hl)
                              r
                              (+ s0 1)
                              e0)))
                        (set await-style (directive-arg-style token))
                        (when (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptNeg" r s0 e0))
                        (let [core (if (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                                        (string.sub token 2)
                                        token)]
                          (when (and (> (# core) 0)
                                     (not= nil (string.find core "[\\%[%]%(%)%+%*%?%|]")))
                            (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptRegex" r s0 e0)))
                        (when (and (> (# token) 0) (= (string.sub token 1 1) "^"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r s0 (+ s0 1)))
                        (when (and (> (# token) 0) (= (string.sub token (# token)) "$"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r (- e0 1) e0))
                        (set pos (+ e 1))))))))
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
        (= action "cancel")
        (fn [] (router.cancel session.prompt-buf))
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

    (fn feed-results-normal-key!
      [key]
      (vim.api.nvim_feedkeys
        (vim.api.nvim_replace_termcodes key true false true)
        "n"
        false))

    (fn set-pending-structural-edit!
      [session side]
      (when (and session.results-edit-mode session.meta session.meta.win
                 (vim.api.nvim_win_is_valid session.meta.win.window))
        (let [row (. (vim.api.nvim_win_get_cursor session.meta.win.window) 1)
              idx (. (or session.meta.buf.indices []) row)
              ref (and idx (. (or session.meta.buf.source-refs []) idx))]
          (when (and ref ref.path ref.lnum)
            (set session.pending-structural-edit
                 {:path ref.path
                  :lnum ref.lnum
                  :side side
                  :kind (or ref.kind "")})))))

    (fn apply-results-edit-keymaps
      [session]
      (let [opts {:buffer session.meta.buf.buffer :silent true :noremap true :nowait true}]
        (vim.keymap.set "n" "o"
          (fn []
            (set-pending-structural-edit! session "after")
            (feed-results-normal-key! "o"))
          opts)
        (vim.keymap.set "n" "O"
          (fn []
            (set-pending-structural-edit! session "before")
            (feed-results-normal-key! "O"))
          opts)
        (vim.keymap.set "n" "p"
          (fn []
            (set-pending-structural-edit! session "after")
            (feed-results-normal-key! "p"))
          opts)
        (vim.keymap.set "n" "P"
          (fn []
            (set-pending-structural-edit! session "before")
            (feed-results-normal-key! "P"))
          opts)))

    (fn begin-direct-results-edit!
      [session]
      (when (and sign-mod session.meta session.meta.buf
                 (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
        (let [buf session.meta.buf.buffer
              internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                          (and ok v))
              manual? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_manual_edit_active")]]
                        (and ok v))]
          (when-not (or internal? manual?)
            (set session.results-edit-mode true)
            (pcall sign-mod.capture-baseline! session)
            (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" true)))))

    (fn register!
  [router session]
      (let [aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true})]
        (set session.augroup aug)

    (fn au!
      [events buf body]
      "Create buffer-local autocmd with schedule-when-valid session guard.
       `body` is a zero-arg function called inside the scheduled guard."
      (vim.api.nvim_create_autocmd events
        {:group aug
         :buffer buf
         :callback (fn [_]
                     (schedule-when-valid session body))}))
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
                             (maybe-show-directive-help! session)
                             (maybe-trigger-directive-complete! session)
                             (on-prompt-changed
                               session.prompt-buf
                               false
                               (vim.api.nvim_buf_get_changedtick session.prompt-buf)))))})
      ;; Re-assert prompt maps when entering insert mode; this wins over late
      ;; plugin mappings (for example completion plugins).
        (au! "InsertEnter" session.prompt-buf
          (fn []
            (events.send :on-insert-enter! {:session session})
            (apply-keymaps router session)
            (apply-emacs-insert-fallbacks router session)))
      ;; Some statusline plugins or focus transitions (for example tmux pane
      ;; switches) can overwrite local statusline state. Re-apply ours when the
      ;; prompt window regains focus.
        (au! ["BufEnter" "WinEnter" "FocusGained"] session.prompt-buf
          (fn [] (pcall session.meta.refresh_statusline)))
      ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
        (au! ["ModeChanged" "InsertEnter" "InsertLeave"] session.prompt-buf
          (fn []
            (pcall session.meta.refresh_statusline)
            (maybe-show-directive-help! session)))
        (au! ["CursorMoved" "CursorMovedI"] session.prompt-buf
          (fn [] (maybe-show-directive-help! session)))
      (au! ["BufEnter" "WinEnter" "FocusGained"] session.prompt-buf
        (fn []
          (when maybe-refresh-preview-statusline!
            (pcall maybe-refresh-preview-statusline! session))
          (when maybe-refresh-info-statusline!
            (pcall maybe-refresh-info-statusline! session))))
      ;; Recompute floating info rendering/width when editor windows resize.
      ;; Guard: both VimResized/WinResized and OptionSet "wrap" can trigger
      ;; on-update which re-renders and may cause further resize/option events.
      ;; The reentrancy flag is set synchronously in the autocmd callback
      ;; (before vim.schedule) so that additional events queued before the
      ;; scheduled callback runs are suppressed.
      ;; On WinResized, capture v:event.windows synchronously — if the preview
      ;; window is in the list (user dragged a split border), latch
      ;; preview-user-resized? so ensure-preview-width! respects the manual
      ;; width.  VimResized (terminal resize) clears the latch.
        (vim.api.nvim_create_autocmd ["VimResized" "WinResized"]
          {:group aug
           :callback (fn [ev]
                       (when-not session.handling-layout-change?
                         ;; Synchronous: capture resize info before schedule.
                         (let [is-vim-resized? (= ev.event "VimResized")]
                           (when is-vim-resized?
                             (set session.preview-user-resized? false))
                           (when (and (not is-vim-resized?)
                                      session.preview-win
                                      (vim.api.nvim_win_is_valid session.preview-win))
                             (let [wins (or (?. vim.v :event :windows) [])]
                               (each [_ wid (ipairs wins)]
                                 (when (= wid session.preview-win)
                                   (set session.preview-user-resized? true))))))
                         (set session.handling-layout-change? true)
                         (schedule-when-valid session
                           (fn []
                             (let [results-wrap? (and session.meta
                                                      session.meta.win
                                                      (vim.api.nvim_win_is_valid session.meta.win.window)
                                                      (vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window}))]
                               (when (and results-wrap? rebuild-source-set!)
                                 (pcall rebuild-source-set! session)
                                 (pcall session.meta.on-update 0)))
                             (when-not session.prompt-animating?
                               (pcall refresh-prompt-highlights! session)
                               (when update-preview-window
                                 (pcall update-preview-window session))
                               (pcall update-info-window session))
                             (set session.handling-layout-change? false)))))} )
        (vim.api.nvim_create_autocmd "OptionSet"
          {:group aug
           :pattern "wrap"
           :callback (fn [_]
                       (when-not session.handling-layout-change?
                         (set session.handling-layout-change? true)
                         (schedule-when-valid session
                           (fn []
                             (when (and session.meta
                                        session.meta.win
                                        (vim.api.nvim_win_is_valid session.meta.win.window)
                                        (= (vim.api.nvim_get_current_win) session.meta.win.window))
                               (let [wrap? (clj.boolean (vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window}))]
                                 (pcall vim.api.nvim_set_option_value "linebreak" wrap? {:win session.meta.win.window})
                                 (when rebuild-source-set!
                                   (pcall rebuild-source-set! session)
                                   (pcall session.meta.on-update 0)
                                   (pcall update-info-window session true)
                                   (when update-preview-window
                                     (pcall update-preview-window session)))))
                             (set session.handling-layout-change? false)))))})
      ;; Keep selection/status/info synced when user scrolls or moves in the
      ;; main meta window with regular motions/mouse while prompt is open.
        (au! ["CursorMoved" "CursorMovedI"] session.meta.buf.buffer
          (fn [] (maybe-sync-from-main! session)))
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (begin-direct-results-edit! session))})
        (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (when (and sign-mod session.meta session.meta.buf)
                         (let [buf session.meta.buf.buffer
                               internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                                           (and ok v))]
                           (when-not internal?
                             (begin-direct-results-edit! session))
                           (vim.schedule
                             (fn []
                               (when (and session.prompt-buf
                                          (= (. active-by-prompt session.prompt-buf) session))
                                 (pcall router.sync-live-edits session.prompt-buf)
                                 (pcall maybe-sync-from-main! session true)
                                 (pcall update-info-window session true)
                                 (pcall sign-mod.refresh-change-signs! session)))))))})
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :buffer session.meta.buf.buffer
            :callback (fn [_]
                        (when (and (not session.closing)
                                   session.meta
                                   session.meta.buf
                                   (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
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
                              (when (and (not session.closing)
                                         session.prompt-buf
                                         (= (. active-by-prompt session.prompt-buf) session))
                              (pcall maybe-restore-hidden-ui! session))))))})
        (vim.api.nvim_create_autocmd "WinNew"
          {:group aug
           :callback (fn [_]
                       (vim.defer_fn
                         (fn []
                           (when (and hide-visible-ui!
                                      (not session.ui-hidden)
                                      session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (let [win (vim.api.nvim_get_current_win)]
                               (when (covered-by-new-window? session win)
                                 (pcall hide-visible-ui! session)))))
                         20))})
        (vim.api.nvim_create_autocmd "BufWinEnter"
          {:group aug
           :callback (fn [ev]
                       (vim.defer_fn
                         (fn []
                           (when (and hide-visible-ui!
                                      (not session.ui-hidden)
                                      session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (let [buf (or ev.buf (vim.api.nvim_get_current_buf))
                                   win (or (first-window-for-buffer buf)
                                           (vim.api.nvim_get_current_win))]
                               (when (or (transient-overlay-buffer? buf)
                                         (covered-by-new-window? session win))
                                 (pcall hide-visible-ui! session)))))
                         20))})
        (au! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn [] (pcall session.meta.refresh_statusline)))
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :callback (fn [_]
                       (vim.schedule
                         (fn []
                           (when (and session.ui-hidden
                                      session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session)
                                      (not (hidden-session-reachable? session)))
                             (pcall router.remove-session session)))))} )
        (vim.api.nvim_create_autocmd "BufLeave"
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       ;; When leaving the results buffer, check if the window it
                       ;; was in is now showing something else. Project-mode
                       ;; sessions should hide auxiliary UI and remain resumable;
                       ;; regular sessions can close entirely.
                       (vim.schedule
                         (fn []
                           (when (and (not session.ui-hidden)
                                      session.prompt-buf
                                      (vim.api.nvim_buf_is_valid session.prompt-buf)
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (let [win session.meta.win.window]
                               (if (not (vim.api.nvim_win_is_valid win))
                                   (router.cancel session.prompt-buf)
                                   (let [buf (vim.api.nvim_win_get_buf win)]
                                     (when (not= buf session.meta.buf.buffer)
                                       (if (and session.project-mode hide-visible-ui!)
                                           (hide-visible-ui! session.prompt-buf)
                                           (router.cancel session.prompt-buf))))))))))})
        (apply-main-keymaps router session)
        (apply-results-edit-keymaps session)
      ;; External file writes: invalidate cached file data and rebuild sources
      ;; so the info sidebar reflects the latest on-disk state.
        (vim.api.nvim_create_autocmd "BufWritePost"
          {:group aug
           :callback (fn [ev]
                       (vim.schedule
                         (fn []
                           (when (and session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session)
                                      (not session.closing))
                             (let [buf (or ev.buf (vim.api.nvim_get_current_buf))]
                               (when (and (vim.api.nvim_buf_is_valid buf)
                                          (not= buf session.meta.buf.buffer))
                                 (let [raw (vim.api.nvim_buf_get_name buf)
                                       path (when (and raw (~= raw ""))
                                              (vim.fn.fnamemodify raw ":p"))]
                                   (when path
                                     ;; Clear per-session caches for this path.
                                     (when session.preview-file-cache
                                       (set (. session.preview-file-cache path) nil))
                                     (when session.info-file-head-cache
                                       (set (. session.info-file-head-cache path) nil))
                                     (when session.info-file-meta-cache
                                       (set (. session.info-file-meta-cache path) nil))
                                     ;; Clear router-level project file cache entry.
                                     (when router.project-file-cache
                                       (set (. router.project-file-cache path) nil))
                                     ;; Rebuild project source set and refresh info window.
                                     (when rebuild-source-set!
                                       (pcall rebuild-source-set! session))
                                      (pcall update-info-window session true)))))))))})
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
        (refresh-prompt-highlights! session)
        (maybe-show-directive-help! session)
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
