# This is another core plugin feature.

We want to be able to get results from other things than just text files.
Primarily this will be for LSP results (functions etc), which should also be prioritized and have appropriate floating window information.
The actual trick is that this works exactly the same, so that edits are propagated back to source.
That is, changing an LSP result would properly rename it, moving a function symbol to a different file would move the entire function definition, etc.

We probably want to build some kind of more proper "source" architecture/plugin type thing for this.
Think autocompletion framework, just much bigger in sophistication.

Also see files support in 03_2 feature.
We should be able to (without a "real" query) for example only show changed and unstaged, or staged, or both, git hunks for files in project.

Other sources (to be implemented only once above is in place and working):
[] search git commit history in general, open commit (or file at commit) on <CR>
[] gh prs (incl desc, commit messages)/git branches
[] search git history for a file (what the code has been)
  - including specifying between which commits to perform search (HEAD to -20 touching that file/hunk, or something by default)
  - show ts, rev and blame in info window
  - hits from different commits on separate lines and functions normally like how does for files
[] search vimdocs (prefilter but then bring in all the different files/lines with hits)

[] open tmux panes scrollback search
  - [] with full ascii highlighting
[] open browser tabs text search (and even history text contents later on if have that side of browser integration)
[] pass a url, fetch its repo and search in it on the fly

