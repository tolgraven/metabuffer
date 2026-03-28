# File for tracking stuff I think of while you work

## These are to be checked off as they are completed, and later (assuming previously committed to git) manually cleared so as to not clutter.
- 1 [x] Any earlier hlsearch should be cleared when invoking Meta.
- 2 [x] prompt window scratch buffer should also be renamed (to the same as existing statusline) so looks better when navigating away from tmux split and airline or similar does a statusline modification overriding us.
- 3 [x] rework all files per guidelines in AGENTS.md, especially around function definitions (separate line, small docstr).
- 4 [x] change the keymaps to use builder functions rather than tons of redundant repetition.
- 5 [x] MOVED TO FEATURE: lazy hits in general. stream results if Meta! init > 100ms, don't wait for them all. (additional debounce for each incoming chunk)
- 6 [x] inspect entire Fennel codebase (exception nfnl/) for mutability and similar. Rework so that things are pure if that is feasible, only mutate when absolutely necessary (due to performance or otherwise).
- 7 [x] closing bang mode incurs a noticable delay. We should unload buffers async and in background, and only after closing our windows etc.
- 8 [x] if lines are very indented we can't see much of them in either the main hit buffer or preview. adjust preview to scroll sideways appropriately, to fit more in view.
- 9 [x] changing the prompt window height now made the info window half as tall as it should be
- 10 [x] when invoking something like `:Meta! end` the insert cursor stays before the text instead of after
- 11 [x] regular cursorline highlight doesn't apply, except for the underline I have in insert mode. But the background gets overridden by the window/buffer background highlighting.
- 12 [x] the preview window should show what file it's showing. best would be to put this in the main statusline. Compact the existing statusline to make space by using short forms for the flags: hidden -> hid, ignored -> ig, deps -> dep, prefilter -> prf, lazy -> lz. Also lazy is core default  and assumed, so don't show that unless nolazy (-> nlz). The text should go right underneath where the preview window starts so matches up.
- 13 [x] Syntax highlighting in hit buffer can often get crazy due to regions showing non-consecutive lines. This might get fixed when we try to use Treesitter and hiding lines instead, but first we should try to reset highlight for each new non-consecutive line, that is, have separate regions for them.
- 14 [x] Sluggish on <CR>: there is a weird delay when opening a hit, even in same file. It should make the jump first and only then do regular teardown, async.
- 15 [x] Sluggish when narrowing search: when we only have a few results, and don't input something that might actually broaden results, there should be no need to re-search everything, only the existing hits. This should improve performance greatly.
- 16 [x] If do `!!` from an empty prompt, or running `:Meta !!`, the full settings used with that prompt (including `#deps` etc toggles) should be recalled. When cycling through prompts after this (with <Up> etc) the same should happen.
- 17 [x] History search suboptimal: typing `##` just gives a floating popup window (in the way of and hiding prompt input - should go above) saying "No history matches". 
- 18 [x] Prompt height changes get captured correctly and restore, but not if closing nvim and opening it again. Should be properly persistent.
- 19 [x] <CR> in results buffer results in "E5108: Error executing lua: ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:329: attempt
to call local 'open_fn' (a nil value)
stack traceback:
        ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:329: in function 'open_selected_h
it_21'
        ...IM/LISTA/metabuffer/metabuffer/lua/metabuffer/router.lua:353: in function <...IM/LISTA/met
abuffer/metabuffer/lua/metabuffer/router.lua:332>"
- 20 [x] Meta "takes over" the entire nvim tab instead of just the area around the active window. Everything should be window-local (but user togglable with a flag).
- 21 [x] lua error when trying to filter a buffer that's already empty (such as :enew)
- 22 [x] info window with hit source info updates correctly when deleting filter, and updates, but hit buffer does not update.
- 23 [x] if type filter like "lua", then deleting it, then "lua" again, selected line gets reset to line 1, should be recalled properly.
- 24 [] lazy file reading regression, when narrowing a search it does a full re-run and all the sources except the original when Meta! started disappear for a short while then reappear. Remember when narrowing (making word longer, or making negation shorter) we want to keep all the sources loaded and only re-run filter on those lines actually present. 
- 25 [x] both the floating info window and the preview window get regular statuslines after moving to a different tmux split (and stay as such when go back to focusing nvim split)
- 26 [x] a small floating window popup showing keybinds, all possible #commands and #toggles and #flags (full names unlike the prompt statusline), options etc. `#?` in prompt should be consumed and open/focus it. q or <Esc> close it.
- 27 [x] even just inserting a space (which does nothing but separate tokens) full filtering re-runs (or at least sources get reloaded). Shouldn't happen.
- 28 [x] project mode gets opened with only about 2000 total possible lines, but project has many many more (even excluding deps, hidden etc). Something is wrong. Faulty prefilter when doing straight `:Meta!`?
- 29 [x] fake preview window line number column has line numbers after end of file.
- 29 [x] preview window should anchor one line higher so gets 8 lines by default.
- 30 [x] we should properly document all required (rg etc) and optional dependencies, and document what having those entails.
- 31 [x] is there any way to speed up the full screen tests in general? they're now taking 8s or so. can we run more tests in parallell instead? (Assessed: 126 files in ~8s, 28 workers with 2× CPU oversubscribe, longest-first scheduling, unit batching 10/batch. Critical path is the ~3s slowest screen tests which can't be split without adding Neovim child startup overhead. Already highly optimized.)
- 32 [x] airline continously overwrites statusline, which was not the case earlier. timing change thing?
- 33 [x] there is a white line dividing prompt window and preview window. it should be removed.
- 34 [x] in project mode, there is a jump once loader inevitably runs into a file longer than 999 lines (which most file we start from will be), so we should pin lineno col to width 3 from start, but then dynamically allow the full 4 _if they are in view_
- 35 [x] when exiting regular `:Meta` mode with `<Esc>`, the viewport jumps. Should stay still.
- 36 [x] in project mode, selecting a result and trying to jump to it with <CR> just restores the position that existed before starting `:Meta`
- 37 [x] in project mode, info window gets stuck on "finalizing results" instead of showing the info lines once loaded
- 38 [x] statusline seems to get stuck under our control, at least Airline isn't being re-enabled.
- 39 [x] write a wrapper/helper for `vim.api.nvim_create_autocmd` for use in prompt/hooks.fnl and anywhere else appropriate. This will inject the correct group, session, and just be passed the inner function on the callback (to be wrapped in schedule-when-valid).
- 40 [x] there is sometimes a flash when scrolling with `<C-d>` etc, one frame where the viewport jumps down several hundred lines then back. This appears to be because the nvim selected line and our model of it are out of sync. Ensure they always update in tandem and that what's visible is what we read. Or just always read it directly...
- 41 [x] if changing lines starts lagging behind due to updating info and preview buffers, we should skip directly to the latest directly, "dropping frames" so to speak, and not building up a queue of movements. Bundle them together instead. However, we should also profile what exactly is taking long when changing lines. This entire thing also applies to page scrolling with <C-d> etc.
- 42 [x] <C-d> etc behaves weird at start and end. Should jump to first and last line respectively if that's closer than where it wants to go.
- 43 [x] look into using mini.nvim git stuff, might be faster and more complete than ours. (Research: features/research/43-mini-git.md — recommend staying with custom blame)
- 44 [x] linewrap setting should persist across sessions for preview window.
- 45 [x] if i run a query like `(fn \n set \n #file source` it should do what you think: search those files matching "source" for lines matching "(fn" or "set". Currently it only shows the actual files.
- 46 [x] The "basic launch smoke tests" that run with all other tests should only run on screen tests, not unit tests.
- 47 [x] when jumping to a hit (at least a `#file search` hit) it's not opened by relative path but instead absolute.
- 48 [x] rainbowparantheses doesn't re-enable (nor is enabled on nvim startup, even not having launched meta...) after exiting Meta. We only disable it while in project mode for performance reasons.
- 49 [x] if windows are resized not due to user resizing height of prompt manually, but by something like :messages opening, they should be restored to where they were automatically once offender is gone.
- 50 [x] should be able to insert a new line in prompt from insert with <S-CR> or something like that, to not jump to hit.
- 51 [x] once again meta sometimes reopens just after having closed it.
- 52 [x] in addition to #hex we should have #b64 that first decodes from base64 before displaying/filtering. (only for strings that are obviously base64). We should not have #hex and #b64 as separate sources, but another category, perhaps "transforms". #bplist would be another example of a transform to implement. Pretty-print json/xml/css yet another good one.
- 53 [x] db sources. would run sql query instead of regular filter, and edits would UPDATE etc on write? especially if you don't even need to properly write the query but can hot-swap it in through LLM interop. (Research: features/research/53-db-sources.md)
- 54 [x] we need an alternative project mode that searches only all loaded buffers (this will also allow stuff like filtering terminal output, other plugin windows' output etc without building specific support in) (Research: features/research/54-all-buffers-mode.md)
- 55 [x] the info window is now one line too tall and covers the main statusline.
- 56 [x] the filter has completely stopped working, and the info window doesn't show anything
- 57 [x] when jumping to line/file with <CR> and no active filter, move cursor to first char on line.
- 58 [x] can't move around results buffer when it's actually focused, keeps jumping back to origin.
- 59 [x] can't resize preview window width without UI lockup and strange behavior
- 60 [x] project mode :Meta! no longer pulling in other sources/files than the one started in
- 61 [x] after typing `#file` and space files load properly, but then typing something after the space doesn't actually filter.
- 62 [x] the completion popup sometimes gets in the way of seeing the prompt cursorline, and sometimes doesn't close as it should.
- 63 [x] the info window loading view is not updating quickly enough, often showing only something like (51/300) and then skipping straight to done. Make it run at at least 10 fps...
- 64 [x] too much time is spent thinking -> run fennel-ls --lint -> thinking -> run compile -> thinking -> run test. These should all go sequentially (with abort on errors) in one call. Create a `make full` shortcut to do this, and note down to use it.
- 65 [x] file extensions are still not showing their color highlight as used to be the case. Neither are file glyphs colored.
- 66 [x] `#file` mode broken if there is already other input before typing `#file`. Also we should simplify file search by using the format `#file:filter` (optionally quoted like `#f:"multiple words"`) for consistency and simplicity. This way we're never ambiguous.
- 67 [] `#exp` should only run for hits in view, much too slow otherwise.
- 68 [] `#ctx` / `#c` which acts similarly to `#exp` but: creates 3 splits, main hits in middle. Callers, globals etc referenced in a fn on the left, called fns on the right.
- 69 [] redo info window loading view. Ingest visible stuff directly so there's no flashing, then use a winbar on the info window showing loading progress. If scrolling so fast we haven't loaded info window lines for a page, use breathing placeholders while loading, never show an empty screen in info.
- 70 [] winbar for results view showing treesitter-derived info for the predominant category of selected line. For example, if on a fn signature it would show something like "fn abcd, 30 lines, called 27 places, makes 7 calls"
- 71 [] popup help window still gets in the way of current prompt line, needs to be further up. And still isn't always being closed properly. And should get equivalent syntax highlighting as prompt buffer itself.
- 72 [] info window still sometimes fails to update when ready, instead one needs to change selected line and it'll update correctly. Can get stuck on loading indicator, can get stuck empty, can get stuck showing wrong thing (after starting `#file` for example).
- 73 [] meta doesn't update file cache even when closed and restarted (possibly due to session reusage?). Need a refresh keybind for now, and (later on) file watcher support.
