The main "all" filter mode should have some nice shortcuts.
Mainly ! to negate a search (filter out) (this should also make the word highlight in red), but also other regex-like quick shortcuts (^, $)
We also want a shortcut for the main results buffer (if moving into it from prompt) where you can exclude the symbol under cursor (use ! as well)
In both insert and normal we also want some quick shell bindings such as !! (insert last prompt, so like <Up> but inline) and !$ for last token of last prompt (should then be cyclable with <Up>/<Down>)

General highlighting of the input is also important. We'll do advanced regex highlighting later, for now just the basics.
