(local key_mod (require :metabuffer.prompt.key))
(local ks_mod (require :metabuffer.prompt.keystroke))
(local util (require :metabuffer.prompt.util))

(local M {})

(fn parse_flags [flags]
  (local out {:noremap false :nowait false :expr false})
  (each [_ flag (ipairs (vim.split (or flags "") " " {:trimempty true}))]
    (if (= flag "noremap")
        (tset out :noremap true)
        (if (= flag "nowait")
            (tset out :nowait true)
            (if (= flag "expr")
                (tset out :expr true)
                (error (.. "Unknown flag \"" flag "\" has specified."))))))
  out)

(fn parse_definition [nvim rule]
  (let [lhs (. rule 1)
        rhs (. rule 2)
        flags (. rule 3)
        opts (parse_flags flags)]
    {:lhs (ks_mod.parse nvim lhs)
     :rhs (if opts.expr rhs (ks_mod.parse nvim rhs))
     :noremap opts.noremap
     :nowait opts.nowait
     :expr opts.expr}))

(fn _getcode [timeoutlen callback interval]
  (local start (vim.loop.hrtime))
  (local timeout_ms (and timeoutlen (math.floor (* timeoutlen 1000))))
  (var done false)
  (var out nil)
  (while (not done)
    (when callback (callback))
    (local code (util.getchar false))
    (if (~= code 0)
        (do (set out code) (set done true))
        (do
          (when timeout_ms
            (local elapsed (/ (- (vim.loop.hrtime) start) 1000000))
            (when (>= elapsed timeout_ms)
              (set done true)))
          (when (not done)
            (vim.wait (math.floor (* (or interval 0.033) 1000)))))))
  out)

(fn M.new []
  (local self {:registry {}})

  (fn self.clear []
    (set self.registry {}))

  (fn self.register [definition]
    (tset self.registry (tostring definition.lhs) definition))

  (fn self.register_from_rule [nvim rule]
    (self.register (parse_definition nvim rule)))

  (fn self.register_from_rules [nvim rules]
    (each [_ rule (ipairs rules)]
      (self.register_from_rule nvim rule)))

  (fn self.filter [lhs]
    (local out [])
    (local probe (tostring lhs))
    (each [_ def (pairs self.registry)]
      (when (vim.startswith (tostring def.lhs) probe)
        (table.insert out def)))
    (table.sort out (fn [a b] (< (tostring a.lhs) (tostring b.lhs))))
    out)

  (fn self._resolve [nvim definition]
    (local rhs (if definition.expr
                   (ks_mod.parse nvim (vim.fn.eval definition.rhs))
                   definition.rhs))
    (if definition.noremap rhs (self.resolve nvim rhs true)))

  (fn self.resolve [nvim lhs nowait]
    (local candidates (self.filter lhs))
    (local n (# candidates))
    (if (= n 0)
        lhs
        (if (= n 1)
            (let [d (. candidates 1)]
              (if (= (tostring d.lhs) (tostring lhs))
                  (self._resolve nvim d)
                  nil))
            (if nowait
                (let [d (. candidates 1)]
                  (if (= (tostring d.lhs) (tostring lhs))
                      (self._resolve nvim d)
                      nil))
                (let [d (. candidates 1)]
                  (if (and d.nowait (= (tostring d.lhs) (tostring lhs)))
                      (self._resolve nvim d)
                      nil))))))

  (fn self.harvest [nvim timeoutlen callback interval]
    (var previous nil)
    (var resolved nil)
    (while (not resolved)
      (local code (_getcode timeoutlen callback interval))
      (if (and (= code nil) (= previous nil))
          (do)
          (if (= code nil)
              (set resolved (or (self.resolve nvim previous true) previous))
              (let [k (key_mod.parse nvim code)]
                (set previous (if previous
                                  (ks_mod.concat previous [k])
                                  (ks_mod.parse nvim [k])))
                (local ks (self.resolve nvim previous false))
                (when ks
                  (set resolved ks))))))
    resolved)

  self)

(fn M.from_rules [nvim rules]
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
