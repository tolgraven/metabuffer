# This is another core plugin feature.

We want to be able to get (deduplicated) results from other things than just text files.
Primarily this will be for LSP results (functions etc), which should also be prioritized and have appropriate floating window information.
The actual trick is that this works exactly the same, so that edits are propagated back to source.
That is, changing an LSP result would properly rename it, moving a function symbol to a different file would move the entire function definition, etc.

We probably want to build some kind of more proper "source" architecture/plugin type thing for this.
Think autocompletion framework, just much bigger in sophistication.

Other sources (to be implemented only once above is in place and working):
[] open tmux panes scrollback search
[] open browser tabs text search (and even history text contents later on if have that side of browser integration)
[] pass a url, fetch its repo and search in it on the fly
