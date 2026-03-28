(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local digraph_mod (require :metabuffer.prompt.digraph))
(local util (require :metabuffer.prompt.util))

(local M {})
(set M.ACTION_PATTERN "^([%w_]+:[%w_]+):?(.*)$")
(local STATUS_ACCEPT 1)
(local STATUS_CANCEL 2)
(local INSERT_MODE_INSERT 1)
(local INSERT_MODE_REPLACE 2)

(fn M.new
  []
  "Public API: M.new."
  (let [self {:registry {}}]

  (fn self.clear
  [] (set self.registry {}))
  (fn normalize-action-name
  [name]
    (if (= (type name) "string")
        (string.gsub name "-" "_")
        name))
  (fn hyphen-action-name
  [name]
    (if (= (type name) "string")
        (string.gsub name "_" "-")
        name))

  (fn self.register
  [name callback]
    (let [normalized (normalize-action-name name)
          hyphenated (hyphen-action-name normalized)]
      (set (. self.registry normalized) callback)
      (when (~= hyphenated normalized)
        (set (. self.registry hyphenated) callback))))

  (fn self.unregister
  [name fail_silently]
    (if (. self.registry name)
        (set (. self.registry name) nil)
        (when-not fail_silently
          (error name))))

  (fn self.register_from_rules
  [rules]
    (each [_ r (ipairs rules)]
      (self.register (. r 1) (. r 2))))

  (fn self.call
  [prompt action]
    (var name (or (string.match action "^([%w_-]+:[%w_-]+)") action))
    (let [params (or (string.match action "^[%w_-]+:[%w_-]+:(.*)$") "")]
    (set name (normalize-action-name name))
      (let [label (string.match name ":([%w_]+)$")
            alt (and label (.. "prompt:" label))]
        (when (and (not (. self.registry name)) alt (. self.registry alt))
          (set name alt))
        (if (. self.registry name)
            ((. self.registry name) prompt params)
            (error (.. "No action \"" name "\" has registered."))))))

  self))

(fn _accept
  [_ _]
  STATUS_ACCEPT)

(fn _cancel
  [_ _]
  STATUS_CANCEL)

(fn _toggle_insert_mode
  [prompt _]
  (if (= prompt.insert-mode INSERT_MODE_INSERT)
      (set prompt.insert-mode INSERT_MODE_REPLACE)
      (set prompt.insert-mode INSERT_MODE_INSERT)))

(fn M.default-action
  []
  M.DEFAULT_ACTION)

(fn _delete_char_before_caret
  [prompt _]
  (let [l (prompt.caret.get-locus)]
    (when (> l 0)
      (set prompt.text (.. (string.sub prompt.text 1 (- l 1)) (string.sub prompt.text (+ l 1))))
      (prompt.caret.set-locus (- l 1)))))

(fn _delete_word_before_caret
  [prompt _]
  (let [l (prompt.caret.get-locus)]
    (when (> l 0)
      (let [back (prompt.caret.get-backward-text)
            new (string.gsub back "[%w_]+%s*$" "" 1)
            removed (- (# back) (# new))]
        (set prompt.text (.. new (prompt.caret.get-selected-text) (prompt.caret.get-forward-text)))
        (prompt.caret.set-locus (- l removed))))))

(fn _delete_char_after_caret
  [prompt _]
  (when (< (prompt.caret.get-locus) (prompt.caret.tail))
    (set prompt.text
      (.. (prompt.caret.get-backward-text)
          (prompt.caret.get-selected-text)
          (string.sub (prompt.caret.get-forward-text) 2)))))

(fn _delete_word_after_caret
  [prompt _]
  (let [fwd (prompt.caret.get-forward-text)
        trimmed (string.gsub fwd "^%s*[%w_]+%s*" "" 1)]
    (set prompt.text
      (.. (prompt.caret.get-backward-text)
          (prompt.caret.get-selected-text)
          trimmed))))

(fn _delete_char_under_caret
  [prompt _]
  (set prompt.text (.. (prompt.caret.get-backward-text) (prompt.caret.get-forward-text))))

(fn _delete_word_under_caret
  [prompt _]
  (when (~= prompt.text "")
    (let [back (string.gsub (prompt.caret.get-backward-text) "[%w_]+$" "" 1)
          fwd (string.gsub (prompt.caret.get-forward-text) "^[%w_]+" "" 1)]
      (set prompt.text (.. back fwd))
      (prompt.caret.set-locus (# back)))))

(fn _delete_text_before_caret
  [prompt _]
  (set prompt.text (prompt.caret.get-forward-text))
  (prompt.caret.set-locus 0))

(fn _delete_text_after_caret
  [prompt _]
  (set prompt.text (prompt.caret.get-backward-text))
  (prompt.caret.set-locus (# prompt.text)))

(fn _delete_entire_text
  [prompt _]
  (set prompt.text "")
  (prompt.caret.set-locus 0))

(fn _move_caret_to_left
  [prompt _] (prompt.caret.set-locus (- (prompt.caret.get-locus) 1)))
(fn _move_caret_to_right
  [prompt _] (prompt.caret.set-locus (+ (prompt.caret.get-locus) 1)))
(fn _move_caret_to_head
  [prompt _] (prompt.caret.set-locus (prompt.caret.head)))
(fn _move_caret_to_lead
  [prompt _] (prompt.caret.set-locus (prompt.caret.lead)))
(fn _move_caret_to_tail
  [prompt _] (prompt.caret.set-locus (prompt.caret.tail)))

(fn _move_caret_to_one_word_left
  [prompt _]
  (let [txt (prompt.caret.get-backward-text)
        new (string.gsub txt "%S+%s?$" "" 1)
        off (- (# txt) (# new))]
    (prompt.caret.set-locus (- (prompt.caret.get-locus) (if (= off 0) 1 off)))))

(fn _move_caret_to_one_word_right
  [prompt _]
  (let [txt (prompt.caret.get-forward-text)
        new (string.gsub txt "^%S+" "" 1)]
    (prompt.caret.set-locus (+ (prompt.caret.get-locus) 1 (- (# txt) (# new)))))
  )

(fn _move_caret_to_left_anchor
  [prompt _]
  (let [anchor (util.int2char (util.getchar))
        idx (string.find (prompt.caret.get-backward-text) anchor 1 true)]
    (when idx
      (prompt.caret.set-locus (- idx 1)))))

(fn _move_caret_to_right_anchor
  [prompt _]
  (let [anchor (util.int2char (util.getchar))
        idx (string.find (prompt.caret.get-forward-text) anchor 1 true)]
    (when idx
      (prompt.caret.set-locus (+ (prompt.caret.get-locus) idx)))))

(fn _assign_previous_text
  [prompt _]
  (set prompt.text (prompt.history.previous))
  (prompt.caret.set-locus (prompt.caret.tail)))

(fn _assign_next_text
  [prompt _]
  (set prompt.text (prompt.history.next))
  (prompt.caret.set-locus (prompt.caret.tail)))

(fn _assign_previous_matched_text
  [prompt _]
  (set prompt.text (prompt.history.previous-match))
  (prompt.caret.set-locus (prompt.caret.tail)))

(fn _assign_next_matched_text
  [prompt _]
  (set prompt.text (prompt.history.next-match))
  (prompt.caret.set-locus (prompt.caret.tail)))

(fn _paste_from_register
  [prompt _]
  (let [st (prompt.store)]
    (prompt.update-text "\"")
    (prompt.redraw-prompt)
    (let [reg (util.int2char (util.getchar))]
      (prompt.restore st)
      (prompt.update-text (vim.fn.getreg reg)))))

(fn _paste_from_default_register
  [prompt _]
  (prompt.update-text (vim.fn.getreg vim.v.register)))

(fn _yank_to_register
  [prompt _]
  (let [st (prompt.store)]
    (prompt.update-text "'")
    (prompt.redraw-prompt)
    (let [reg (util.int2char (util.getchar))]
      (prompt.restore st)
      (vim.fn.setreg reg prompt.text))))

(fn _yank_to_default_register
  [prompt _]
  (vim.fn.setreg vim.v.register prompt.text))

(fn _insert_special
  [prompt _]
  (let [st (prompt.store)]
    (prompt.update-text "^")
    (prompt.redraw-prompt)
    (let [code (util.getchar)]
      (prompt.restore st)
      (prompt.update-text (util.int2repr (if (= code "<BS>") 8 code))))))

(fn _insert_digraph
  [prompt _]
  (let [st (prompt.store)]
    (prompt.update-text "?")
    (prompt.redraw-prompt)
    (let [dg (digraph_mod.new)
          ch (dg.retrieve dg)]
      (prompt.restore st)
      (prompt.update-text ch))))

(fn _insert_newline
  [prompt _]
  (prompt.update-text "\n"))

(set M.DEFAULT_ACTION (M.new))
(M.DEFAULT_ACTION.register_from_rules
  [ ["prompt:accept" _accept]
    ["prompt:cancel" _cancel]
    ["prompt:toggle_insert_mode" _toggle_insert_mode]
    ["prompt:delete_char_before_caret" _delete_char_before_caret]
    ["prompt:delete_word_before_caret" _delete_word_before_caret]
    ["prompt:delete_char_after_caret" _delete_char_after_caret]
    ["prompt:delete_word_after_caret" _delete_word_after_caret]
    ["prompt:delete_char_under_caret" _delete_char_under_caret]
    ["prompt:delete_word_under_caret" _delete_word_under_caret]
    ["prompt:delete_text_before_caret" _delete_text_before_caret]
    ["prompt:delete_text_after_caret" _delete_text_after_caret]
    ["prompt:delete_entire_text" _delete_entire_text]
    ["prompt:move_caret_to_left" _move_caret_to_left]
    ["prompt:move_caret_to_one_word_left" _move_caret_to_one_word_left]
    ["prompt:move_caret_to_left_anchor" _move_caret_to_left_anchor]
    ["prompt:move_caret_to_right" _move_caret_to_right]
    ["prompt:move_caret_to_one_word_right" _move_caret_to_one_word_right]
    ["prompt:move_caret_to_right_anchor" _move_caret_to_right_anchor]
    ["prompt:move_caret_to_head" _move_caret_to_head]
    ["prompt:move_caret_to_lead" _move_caret_to_lead]
    ["prompt:move_caret_to_tail" _move_caret_to_tail]
    ["prompt:assign_previous_text" _assign_previous_text]
    ["prompt:assign_next_text" _assign_next_text]
    ["prompt:assign_previous_matched_text" _assign_previous_matched_text]
    ["prompt:assign_next_matched_text" _assign_next_matched_text]
    ["prompt:paste_from_register" _paste_from_register]
    ["prompt:paste_from_default_register" _paste_from_default_register]
    ["prompt:yank_to_register" _yank_to_register]
     ["prompt:yank_to_default_register" _yank_to_default_register]
     ["prompt:insert_special" _insert_special]
     ["prompt:insert_digraph" _insert_digraph]
     ["prompt:insert_newline" _insert_newline] ])

M
