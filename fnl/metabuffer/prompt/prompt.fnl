(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local caret_mod (require :metabuffer.prompt.caret))
(local history_mod (require :metabuffer.prompt.history))
(local action_mod (require :metabuffer.prompt.action))
(local keymap_mod (require :metabuffer.prompt.keymap))
(local util (require :metabuffer.prompt.util))
(local debug (require :metabuffer.debug))

(local M {})

(set M.STATUS_PROGRESS 0)
(set M.STATUS_ACCEPT 1)
(set M.STATUS_CANCEL 2)
(set M.STATUS_INTERRUPT 3)
(set M.STATUS_PAUSE 4)

(set M.INSERT_MODE_INSERT 1)
(set M.INSERT_MODE_REPLACE 2)

(set M.DEFAULT_HARVEST_INTERVAL 0.033)

(fn debug-log
  [msg]
  (debug.log "prompt" msg))

(fn is_action_keystroke
  [s]
  (and (= (type s) "string")
       (vim.startswith s "<")
       (vim.endswith s ">")
       (string.match (string.sub s 2 (- (# s) 1)) "^%w+:%w+.*$")))

(fn M.new
  [nvim]
  "Public API: M.new."
  (let [self {:nvim nvim
              :text ""
              :prefix ""
              :insert-mode M.INSERT_MODE_INSERT
              :highlight-prefix "Question"
              :highlight-text "None"
              :highlight-caret "IncSearch"
              :harvest-interval M.DEFAULT_HARVEST_INTERVAL
              :is-macvim (and (= 1 (vim.fn.has "gui_running")) (= 1 (vim.fn.has "mac")))}]
    (set self.caret (caret_mod.new self 0))
    (set self.history (history_mod.new self))
    (set self.action action_mod.DEFAULT_ACTION)
    (set self.keymap (keymap_mod.from_rules nvim keymap_mod.DEFAULT_KEYMAP_RULES))

    (fn self.insert-text
      [txt]
      (let [locus (self.caret.get-locus)]
        (set self.text (.. (self.caret.get-backward-text)
                           txt
                           (self.caret.get-selected-text)
                           (self.caret.get-forward-text)))
        (self.caret.set-locus (+ locus (# txt)))))

    (fn self.replace-text
      [txt]
      (let [locus (self.caret.get-locus)]
        (set self.text (.. (self.caret.get-backward-text)
                           txt
                           (string.sub (self.caret.get-forward-text) (# txt))))
        (self.caret.set-locus (+ locus (# txt)))))

    (fn self.update-text
      [txt]
      (if (= self.insert-mode M.INSERT_MODE_INSERT)
          (self.insert-text txt)
          (self.replace-text txt)))

    (fn self.redraw-prompt
      []
      (let [backward (self.caret.get-backward-text)
            selected (self.caret.get-selected-text)
            forward (self.caret.get-forward-text)]
        (vim.cmd
          (table.concat
            ["redraw"
             (util.build_echon_expr self.prefix self.highlight-prefix)
             (util.build_echon_expr backward self.highlight-text)
             (util.build_echon_expr selected self.highlight-caret)
             (util.build_echon_expr forward self.highlight-text)]
            "|"))
        (when self.is-macvim
          (vim.cmd "redraw"))))

  (fn self.on-init
  []
    (vim.fn.inputsave))

  (fn self.on-update
  [status]
    status)

  (fn self.on-redraw
  []
    (self.redraw-prompt))

  (fn self.on-harvest
  [] nil)

    (fn self.on-keypress
      [keystroke]
      (let [s (tostring keystroke)]
        (if (is_action_keystroke s)
            (let [action (string.sub s 2 (- (# s) 1))
                  ret (self.action.call self action)]
              ;; Only numeric return values are treated as prompt statuses.
              ;; Side-effect actions may return ""/other truthy values (from vim.cmd),
              ;; which must not terminate the prompt loop.
              (when (= (type ret) "number") ret))
            (self.update-text s))))

  (fn self.on-term
  [status]
    (vim.fn.inputrestore)
    status)

  (fn self.store
  []
    {:text self.text
     :caret-locus (self.caret.get-locus)})

  (fn self.restore
  [condition]
    (set self.text condition.text)
    (self.caret.set-locus condition.caret-locus))

    (fn self.start
      []
      (var status (or (self.on-init) M.STATUS_PROGRESS))
      (debug-log (.. "[prompt] start status=" (tostring status)))
      (let [timeoutlen (when vim.o.timeout (/ vim.o.timeoutlen 1000.0))]
        (let [[ok err] [(pcall
                          (fn []
                            (set status (or (self.on-update status) M.STATUS_PROGRESS))
                            (debug-log (.. "[prompt] post-init-update status=" (tostring status)))
                            (while (= status M.STATUS_PROGRESS)
                              (self.on-redraw)
                              (let [stroke (self.keymap.harvest self.nvim timeoutlen self.on-harvest self.harvest-interval)]
                                (debug-log (.. "[prompt] stroke=" (tostring stroke)))
                                (set status (or (self.on-keypress stroke) M.STATUS_PROGRESS))
                                (debug-log (.. "[prompt] post-keypress status=" (tostring status)))
                                (set status (or (self.on-update status) status))))))]]
          (when (not ok)
            (debug-log (.. "[prompt] error=" (tostring err)))
            (if (or (= err "Keyboard interrupt") (string.find (tostring err) "Keyboard interrupt"))
                (set status M.STATUS_INTERRUPT)
                (error err)))))
      (when (~= self.text "")
        (vim.fn.histadd "input" self.text))
      (debug-log (.. "[prompt] term status=" (tostring status)))
      (self.on-term status))

    self))

M
