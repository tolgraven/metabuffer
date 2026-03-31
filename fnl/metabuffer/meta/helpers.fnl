(import-macros {: when-let} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local directive-mod (require :metabuffer.query.directive))
(local statusline_mod (require :metabuffer.window.statusline))
(local util (require :metabuffer.util))

(local M {})

(fn session-busy?
  [session]
  (and session
       (or session.prompt-update-pending
           session.prompt-update-dirty
           session.project-bootstrap-pending
           (and session.project-mode
                (not session.lazy-stream-done))
           (and session.project-mode
                (not session.project-bootstrapped)))))

(fn M.loading-visible?
  [session]
  (and session
       session.loading-indicator?
       (or (session-busy? session)
           (~= session.loading-anim-phase nil)
           session.loading-idle-pending)))

(fn M.results-middle-group
  [session]
  (or (and session
           session.results-statusline-pulse-active?
           "MetaStatuslineMiddlePulse")
      "MetaStatuslineMiddle"))

(fn ping-pong-center
  [phase width]
  (let [w (math.max 1 (or width 1))]
    (if (<= w 1)
        1
        (let [period (math.max 1 (- (* 2 w) 2))
              step (% (or phase 0) period)]
          (if (< step w)
              (+ step 1)
              (- period step -1))))))

(fn status-fragment
  [group text]
  (if (or (= (type text) "nil") (= text ""))
      ""
      (.. "%#" group "#" (string.gsub text "%%" "%%%%"))))

(fn results-group
  [session group]
  (or (and session
           session.results-statusline-pulse-active?
           (.. group "Pulse"))
      group))

(fn project-flag-fragment
  [session name on?]
  (.. (status-fragment (results-group session "MetaStatuslineKey") (if on? "+" "-"))
      (status-fragment (results-group session (if on? "MetaStatuslineFlagOn" "MetaStatuslineFlagOff")) name)))

(fn loading-fragment
  [session]
  (if (M.loading-visible? session)
      (let [word "Working"
            phase (or session.loading-anim-phase 0)
            center (ping-pong-center phase (# word))
            out []]
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
            (table.insert out (status-fragment hl (string.sub word i i)))))
        (table.concat out ""))
      ""))

(fn status-flags-fragment
  [session]
  (let [parts []]
    (each [_ item (ipairs (directive-mod.statusline-items session))]
      (let [frag (project-flag-fragment session
                                        (or (. item :label) "")
                                        (clj.boolean (. item :active)))]
        (when (> (# frag) 0)
          (table.insert parts frag))))
    (if (> (# parts) 0)
        (table.concat parts (status-fragment (M.results-middle-group session) "  "))
        "")))

(fn M.results-statusline-left
  [self]
  (let [session self.session
        buf self.buf.buffer
        modified? (and buf
                       (vim.api.nvim_buf_is_valid buf)
                       (. vim.bo buf :modified))
        modified-fragment (if modified?
                              (status-fragment (results-group session "MetaStatuslineIndicator") "[+]")
                              "")
        loading (loading-fragment session)
        debug (or self.debug_out "")
        parts []]
    (when (> (# modified-fragment) 0)
      (table.insert parts modified-fragment))
    (when (> (# loading) 0)
      (table.insert parts loading))
    (when (> (# debug) 0)
      (table.insert parts (status-fragment (results-group session "MetaStatuslineIndicator") debug)))
    (if (= (# parts) 0)
        ""
        (.. " " (table.concat parts (status-fragment (M.results-middle-group session) "  "))))))

(fn M.results-statusline-right
  [self]
  (let [flags (status-flags-fragment self.session)]
    (if (> (# flags) 0)
        (.. " " flags)
        "")))

(fn nerd-font-enabled?
  []
  (or (= (. vim.g "meta#nerd_font") true)
      (= (. vim.g "meta#nerd_font") 1)
      (= vim.g.have_nerd_font true)
      (= vim.g.have_nerd_font 1)
      (= vim.g.nerd_font true)
      (= vim.g.nerd_font 1)))

(fn statusline-mode-state
  []
  (let [m (or (. (vim.api.nvim_get_mode) :mode) "")]
    (if (vim.startswith m "R")
        {:group "Replace" :label (if (nerd-font-enabled?) "R" "Replace")}
        (vim.startswith m "i")
        {:group "Insert" :label (if (nerd-font-enabled?) "𝐈" "Insert")}
        {:group "Normal" :label (if (nerd-font-enabled?) "𝗡" "Normal")})))

(fn M.prompt-statusline-text
  [self]
  (let [mode-state (statusline-mode-state)
        matcher (. (self.matcher) :name)
        matcher-suffix (statusline_mod.title-case matcher)
        case-mode (self.case)
        case-suffix (statusline_mod.title-case case-mode)
        hl-prefix (if (= self.buf.syntax-type "meta") "Meta" "Buffer")]
    (string.format
      "%%#MetaStatuslineMode%s# %s %%#MetaStatuslineIndicator# %d/%d %%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s "
      (. mode-state :group)
      (. mode-state :label)
      (# self.buf.indices)
      (self.buf.line-count)
      matcher-suffix matcher "C^"
      case-suffix case-mode "C-o"
      hl-prefix (self.syntax) "Cs")))

(fn M.highlight-pattern->vim-query
  [pat]
  (if (= (type pat) "string")
      pat
      (= (type pat) "table")
      (let [parts []]
        (each [_ item (ipairs pat)]
          (let [item-pat (or (. item :pattern) "")]
            (when (~= item-pat "")
              (table.insert parts item-pat))))
        (if (> (# parts) 0)
            (table.concat parts "\\|")
            ""))
      ""))

(fn ends-with-space?
  [s]
  (let [txt (or s "")
        n (# txt)]
    (and (> n 0)
         (not= nil (string.find (string.sub txt n n) "%s")))))

(fn last-token
  [s]
  (let [txt (or s "")
        n (# txt)]
    (if (or (= n 0) (ends-with-space? txt))
        nil
        (let [start (or (string.match txt ".*()%s%S+$") 1)]
          (string.sub txt start)))))

(fn M.bang-token-completed?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")
        prev-n (# prev0)
        next-n (# next0)]
    (and (> prev-n 0)
         (> next-n prev-n)
         (vim.startswith next0 prev0)
         (= (string.sub prev0 prev-n prev-n) "!")
         (let [before (if (> prev-n 1)
                          (string.sub prev0 (- prev-n 1) (- prev-n 1))
                          "")]
           (and (~= before "\\")
                (or (= prev-n 1)
                    (not= nil (string.find before "%s")))))
         (let [added (string.sub next0 (+ prev-n 1) (+ prev-n 1))]
           (not= nil (string.find added "%S"))))))

(fn negation-growth-broadens?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")]
    (if (or (= prev0 "")
            (not (vim.startswith next0 prev0))
            (<= (# next0) (# prev0))
            (ends-with-space? prev0))
        false
        (let [prev-tok (or (last-token prev0) "")
              next-tok (or (last-token next0) "")
              same-token? (and (~= prev-tok "")
                               (vim.startswith next-tok prev-tok))
              unescaped-bang? (and (> (# prev-tok) 0)
                                   (= (string.sub prev-tok 1 1) "!")
                                   (not (vim.startswith prev-tok "\\!")))]
          (and same-token? unescaped-bang?)))))

(set (. M :negation-growth-broadens?) negation-growth-broadens?)

(fn unescaped-negated-token?
  [tok]
  (let [t (or tok "")]
    (and (> (# t) 1)
         (= (string.sub t 1 1) "!")
         (not (vim.startswith t "\\!")))))

(fn M.deletion-broadens?
  [prev next]
  (let [prev0 (or prev "")
        next0 (or next "")]
    (if (or (= next0 "")
            (not (vim.startswith prev0 next0))
            (>= (# next0) (# prev0)))
        true
        (let [prev-tok (or (last-token prev0) "")
              next-tok (or (last-token next0) "")
              same-token? (and (~= prev-tok "")
                               (~= next-tok "")
                               (vim.startswith prev-tok next-tok))
              negation-shrink? (and same-token?
                                    (unescaped-negated-token? prev-tok)
                                    (unescaped-negated-token? next-tok))]
          (not negation-shrink?)))))

(set (. M :statusline-mode-state) statusline-mode-state)

(fn M.apply-lgrep-highlights!
  [self delete-win-match lgrep-match-ids]
  (each [_ id (ipairs (or (. self lgrep-match-ids) []))]
    (delete-win-match self.win.window id))
  (set (. self lgrep-match-ids) [])
  (when (and self.win self.win.window (vim.api.nvim_win_is_valid self.win.window))
    (let [out []]
      (each [_ spec (ipairs (or (and self.session self.session.last-parsed-query self.session.last-parsed-query.lgrep-lines) []))]
        (when (and spec
                   (= (type spec) "table")
                   (~= (vim.trim (or (. spec :query) "")) ""))
          (table.insert out (vim.trim (or (. spec :query) "")))))
      (each [_ q (ipairs out)]
        (let [pat (.. "\\V" (util.escape-vim-pattern q))
              [ok id] [(pcall vim.fn.matchadd "MetaSearchHitLgrep" pat 215 -1 {:window self.win.window})]]
          (when ok
            (table.insert (. self lgrep-match-ids) id)))))))

(fn M.clear-all-highlights!
  [self delete-win-match lgrep-match-ids]
  (let [matcher-mode (. self.mode :matcher)]
    (when matcher-mode
      (each [_ m (ipairs matcher-mode.candidates)]
        (when m
          (pcall m.remove-highlight m)))))
  (each [_ id (ipairs (or (. self lgrep-match-ids) []))]
    (delete-win-match self.win.window id))
  (set (. self lgrep-match-ids) []))

M
