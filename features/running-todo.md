# File for tracking stuff I think of while you work

## These are to be checked off as they are completed, and later (assuming previously committed to git) manually cleared so as to not clutter.
- 1 [x] Any earlier hlsearch should be cleared when invoking Meta.
- 2 [x] prompt window scratch buffer should also be renamed (to the same as existing statusline) so looks better when navigating away from tmux split and airline or similar does a statusline modification overriding us.
- 3 [x] rework all files per guidelines in AGENTS.md, especially around function definitions (separate line, small docstr).
- 4 [x] change the keymaps to use builder functions rather than tons of redundant repetition.
- 5 [x] MOVED TO FEATURE: lazy hits in general. stream results if Meta! init > 100ms, don't wait for them all. (additional debounce for each incoming chunk)
- 6 [] inspect entire Fennel codebase (exception nfnl/) for mutability and similar. Rework so that things are pure if that is feasible, only mutate when absolutely necessary (due to performance or otherwise).
- 7 [x] closing bang mode incurs a noticable delay. We should unload buffers async and in background, and only after closing our windows etc.
- 8 [x] if lines are very indented we can't see much of them in either the main hit buffer or preview. adjust preview to scroll sideways appropriately, to fit more in view.
- 9 [x] changing the prompt window height now made the info window half as tall as it should be
- 10 [x] when invoking something like `:Meta! end` the insert cursor stays before the text instead of after
- 11 [] regular cursorline highlight doesn't apply, except for the underline I have in insert mode. But the background gets overridden by the window/buffer background highlighting.
- 12 [] the preview window should show what file it's showing. best would be to put this in the main statusline. Compact the existing statusline to make space by using short forms for the flags: hidden -> hid, ignored -> ig, deps -> dep, prefilter -> prf, lazy -> lz. Also lazy is core default  and assumed, so don't show that unless nolazy (-> nlz). The text should go right underneath where the preview window starts so matches up.
- 13 [] Syntax highlighting in hit buffer can often get crazy due to regions showing non-consecutive lines. This might get fixed when we try to use Treesitter and hiding lines instead, but first we should try to reset highlight for each new non-consecutive line, that is, have separate regions for them.
- 14 [] Sluggish on <CR>: there is a weird delay when opening a hit, even in same file. It should make the jump first and only then do regular teardown, async.
- 15 [x] Sluggish when narrowing search: when we only have a few results, and don't input something that might actually broaden results, there should be no need to re-search everything, only the existing hits. This should improve performance greatly.
- 16 [] If do `!!` from an empty prompt, or running `:Meta !!`, the full settings used with that prompt (including `#deps` etc toggles) should be recalled. When cycling through prompts after this (with <Up> etc) the same should happen.
- 17 [] History search suboptimal: typing `##` just gives a floating popup window (in the way of and hiding prompt input - should go above) saying "No history matches". 
- 18 [] Prompt height changes get captured correctly and restore, but not if closing nvim and opening it again. Should be properly persistent.
- 19 [x] <CR> in results buffer results in "E5108: Error executing lua: ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:329: attempt
to call local 'open_fn' (a nil value)
stack traceback:
        ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:329: in function 'open_selected_h
it_21'
        ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:353: in function <...IM/LISTA/met
abuffer/metabuffer/lua/metabuffer/router.lua:332>"
- 20 [] Meta "takes over" the entire nvim tab instead of just the area around the active window. Everything should be window-local (but user togglable with a flag).
- 21 [x] lua error when trying to filter a buffer that's already empty (such as :enew)
