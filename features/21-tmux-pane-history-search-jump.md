# Search tmux panes scrollback history and jump to split

Flag `#tmux` for current window, `#tmux:s` for current session, `#tmux:a` for all
<!-- Dumps scrollback including ansi which we load. Every line needs metadata (info window) about origin (pane, command, time) -->
Dumps scrollback including ansi which we load. Every line needs metadata (info window) about origin (pane, command, time)

Needs baleia.nvim to work with colors.

Maybe a crazy mode where new output in any split ends up in chunks like chatbubbles in a single view as well, more for following along than searching.

Actually general functionality is pretty great for log filtering etc so maybe build some other features around that, formatting etc.
