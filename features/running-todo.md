# File for tracking stuff I think of while you work

## These are to be checked off as they are completed, and later (assuming previously committed to git) cleared so as to not clutter.
- 1 [] earlier hlsearch should be cleared when invoking Meta.
- 2 [] prompt window scratch buffer should also be renamed so looks better when navigating away from tmux split
- 3 [] rework all files per guidelines in AGENTS.md, especially around function definitions (separate line, small docstr).
- 4 [x] change the keymaps to use builder functions rather than tons of redundant repetition.
- 5 [x] MOVED TO FEATURE: lazy hits in general. stream results if Meta! init > 100ms, don't wait for them all. (additional debounce for each incoming chunk)
- 6 [] inspect entire Fennel codebase (exception nfnl/) for mutability and similar. Rework so that things are pure if that is feasible, only mutate when absolutely necessary (due to performance or otherwise).
- 7 [] closing bang mode incurs a noticable delay. We should unload buffers async and in background, and only after closing our windows etc.
- 8 [] if lines are very indented we can't see much of them in either the main hit buffer or preview. adjust preview to scroll sideways appropriately, to fit more in view.
- 9 [] changing the prompt window height now made the info window half as tall as it should be
