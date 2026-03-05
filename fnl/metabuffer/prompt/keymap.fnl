(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local key_mod (require :metabuffer.prompt.key))
(local ks_mod (require :metabuffer.prompt.keystroke))
(local util (require :metabuffer.prompt.util))
(local debug (require :metabuffer.debug))

(local M {})

(fn debug-log
  [msg]
  (debug.log "keymap" msg))

(fn parse_flags
  [flags]
  (local out {:noremap false :nowait false :expr false})
  (each [_ flag (ipairs (vim.split (or flags "") " " {:trimempty true}))]
    (if (= flag "noremap")
        (set out.noremap true)
        (if (= flag "nowait")
            (set out.nowait true)
            (if (= flag "expr")
                (set out.expr true)
                (error (.. "Unknown flag \"" flag "\" has specified."))))))
  out)

(fn parse_definition
  [nvim rule]
  (let [lhs (. rule 1)
        rhs (. rule 2)
        flags (. rule 3)
        opts (parse_flags flags)]
    {:lhs (ks_mod.parse nvim lhs)
     :rhs (if opts.expr rhs (ks_mod.parse nvim rhs))
     :noremap opts.noremap
     :nowait opts.nowait
     :expr opts.expr}))

(fn _getcode
  [timeoutlen callback interval]
  ;; Use blocking getcharstr() so Neovim decodes terminal/tmux escape
  ;; sequences into full key tokens before we resolve mappings.
  (when callback (callback))
  (let [packed [(pcall vim.fn.getcharstr)]
        ok (. packed 1)]
    (when ok
      (let [code (. packed 2)]
        (debug-log (.. "[keymap] raw=" (tostring (vim.fn.keytrans code))))
        code))))

(fn M.new
  []
  (local self {:registry {}})

  (fn self.clear
  []
    (set self.registry {}))

  (fn self.register
  [definition]
    (set (. self.registry (tostring definition.lhs)) definition))

  (fn self.register_from_rule
  [nvim rule]
    (self.register (parse_definition nvim rule)))

  (fn self.register_from_rules
  [nvim rules]
    (each [_ rule (ipairs rules)]
      (self.register_from_rule nvim rule)))

  (fn self.filter
  [lhs]
    (local out [])
    (local probe (tostring lhs))
    (each [_ def (pairs self.registry)]
      (when (vim.startswith (tostring def.lhs) probe)
        (table.insert out def)))
    (table.sort out (fn [a b] (< (tostring a.lhs) (tostring b.lhs))))
    out)

  (fn self._resolve
  [nvim definition]
    (local rhs (if definition.expr
                   (ks_mod.parse nvim (vim.fn.eval definition.rhs))
                   definition.rhs))
    (if definition.noremap rhs (self.resolve nvim rhs true)))

  (fn self.resolve
  [nvim lhs nowait]
    (local candidates (self.filter lhs))
    (local n (# candidates))
    (if (= n 0)
        lhs
        (if (= n 1)
            (let [d (. candidates 1)]
              (when (= (tostring d.lhs) (tostring lhs))
                (self._resolve nvim d)))
            (if nowait
                (let [d (. candidates 1)]
                  (when (= (tostring d.lhs) (tostring lhs))
                    (self._resolve nvim d)))
                (let [d (. candidates 1)]
                  (when (and d.nowait (= (tostring d.lhs) (tostring lhs)))
                    (self._resolve nvim d)))))))

  (fn self.harvest
  [nvim timeoutlen callback interval]
    (var previous nil)
    (var resolved nil)
    (fn feed-key
  [k]
      (set previous (if previous
                        (ks_mod.concat previous [k])
                        (ks_mod.parse nvim [k])))
      (local ks (self.resolve nvim previous false))
      (when ks
        (set resolved ks)))
    (while (not resolved)
      (local code (_getcode timeoutlen callback interval))
      (if (= code nil)
          (when previous
            (set resolved (or (self.resolve nvim previous true) previous)))
          (let [chunk (if (= (type code) "string")
                          (if (string.find code "\128" 1 true)
                              ;; Internal keycode bytes (e.g. <80>kP) must be parsed as one key.
                              [(key_mod.parse nvim code)]
                              (ks_mod.parse nvim code))
                          [(key_mod.parse nvim code)])]
            (each [_ k (ipairs chunk)]
              (when (not resolved)
                (feed-key k))))))
    (debug-log (.. "[keymap] resolved=" (tostring resolved)))
    resolved)

  self)

(fn M.from_rules
  [nvim rules]
  (local km (M.new))
  (km.register_from_rules nvim rules)
  km)

(set M.DEFAULT_KEYMAP_RULES
  [ ["<C-B>" "<prompt:move_caret_to_head>" "noremap"]
    ["<C-E>" "<prompt:move_caret_to_tail>" "noremap"]
    ["<BS>" "<prompt:delete_char_before_caret>" "noremap"]
    ["<C-H>" "<prompt:delete_char_before_caret>" "noremap"]
    ["<S-TAB>" "<prompt:assign_previous_text>" "noremap"]
    ["<C-J>" "<prompt:accept>" "noremap"]
    ["<C-K>" "<prompt:insert_digraph>" "noremap"]
    ["<CR>" "<prompt:accept>" "noremap"]
    ["<C-M>" "<prompt:accept>" "noremap"]
    ["<C-N>" "<prompt:assign_next_text>" "noremap"]
    ["<C-P>" "<prompt:assign_previous_text>" "noremap"]
    ["<C-Q>" "<prompt:insert_special>" "noremap"]
    ["<C-R>" "<prompt:paste_from_register>" "noremap"]
    ["<C-U>" "<prompt:delete_entire_text>" "noremap"]
    ["<C-V>" "<prompt:insert_special>" "noremap"]
    ["<C-W>" "<prompt:delete_word_before_caret>" "noremap"]
    ["<ESC>" "<prompt:cancel>" "noremap"]
    ["<DEL>" "<prompt:delete_char_under_caret>" "noremap"]
    ["<Left>" "<prompt:move_caret_to_left>" "noremap"]
    ["<S-Left>" "<prompt:move_caret_to_one_word_left>" "noremap"]
    ["<C-Left>" "<prompt:move_caret_to_one_word_left>" "noremap"]
    ["<Right>" "<prompt:move_caret_to_right>" "noremap"]
    ["<S-Right>" "<prompt:move_caret_to_one_word_right>" "noremap"]
    ["<C-Right>" "<prompt:move_caret_to_one_word_right>" "noremap"]
    ["<Up>" "<prompt:assign_previous_matched_text>" "noremap"]
    ["<S-Up>" "<prompt:assign_previous_text>" "noremap"]
    ["<Down>" "<prompt:assign_next_matched_text>" "noremap"]
    ["<S-Down>" "<prompt:assign_next_text>" "noremap"]
    ["<Home>" "<prompt:move_caret_to_head>" "noremap"]
    ["<End>" "<prompt:move_caret_to_tail>" "noremap"]
    ["<PageDown>" "<prompt:assign_next_text>" "noremap"]
    ["<PageUp>" "<prompt:assign_previous_text>" "noremap"]
    ["<INSERT>" "<prompt:toggle_insert_mode>" "noremap"] ])

M
