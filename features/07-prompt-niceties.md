The main "all" filter mode should have some nice shortcuts.
Mainly ! to negate a search (filter out) (this should also make the word highlight in red), but also other regex-like quick shortcuts (^, $)
We also want a shortcut for the main results buffer (if moving into it from prompt) where you can exclude the symbol under cursor (use ! as well)
In both insert and normal we also want some quick shell bindings such as !! (insert last prompt, so like <Up> but inline) and !$ for last token of last prompt (should then be cyclable with <Up>/<Down>)

General highlighting of the input is also important. We'll do advanced regex highlighting later, for now just the basics.

## Additions after implementation started
- !^! - insert last prompt except first word
- <LocalLeader>1 and <LocalLeader>! in insert - negate current prompt token (insert ! before, restore cursor pos)
- We need a <C-r> searchback mode. This should use full highlighting for all previous displayed prompts, and utilize a floating window for them (make a new window type in window/ based on floating). Typing should stay in-prompt, but with the search filter text replaced by the selected prompt upon <CR>
- Ensure previous prompts are persistently stored so can resume and search across sessions. But the current session should not be automatically polluted by other concurrent sessions - though we want a keybind and flag (`#history` -> merges prompt history and deletes itself)
- Should be able to save prompts and later insert them. Syntax: `#save:tag`, then `##tag` to restore (`##` by itself should bring up history (based on how `<C-r>` functionality and code, but only showing saved tags and their prompts) and allow inline filtering of them)
- Most `#flags` should do what's needed and then disappear. So `#+deps` would enable deps search and then disappear so doesn't pollute input.
- Common regex stuff like `\w` and similar, groups etc, should automatically enable regex search _only for that token or group_. otherwise keeping normal mode. These should be highlighted by an underline in regex mode color.
- We need to be able to lookback when negating. `!import when-not` and `when-not !import` should be equivalent.
