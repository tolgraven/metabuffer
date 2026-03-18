# Tabs

We might sometimes need multiple views, or jump back and forth between metabuffers, or fork one to edit the prompt further, keeping the old filter results intact.
This should be implemented by a virtual tab bar, implemented as a floating window anchored to the results window bottom. Clicking a tab (instance for the original window region) would switch to it, and we might even want to hijack regular `gt` etc mappings? Optinally at least.
This would also help us do things like "open a new metabuffer instance with complete env for token under cursor, even if already in a metabuffer"
