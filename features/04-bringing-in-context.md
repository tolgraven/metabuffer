This is an advanced feature of the plugin.

When we have a filtered view of hits, we want to be able to bring in the context for each hit, not just show it in the preview.
This means for example bringing in the surrounding lines, but more importantly for LSP and Treesitter, entire surrounding functions for example.
This feature goes beyond mere bulk editing and towards a future kind of code editing where we don't care so much about what file something is in, but rather what relates to it, and instead of splits can get everything relevant for us brought into the same Metabuffer, in some cases automatically.

In the end this will allow both quicker editing for humans, and reduced lookups and context for LLM agents.
