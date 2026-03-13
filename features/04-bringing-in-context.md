# Context expansion
This is an advanced feature of the plugin.

When we have a filtered view of hits, we want to be able to bring in the context for each hit, not just show some of it in the preview.
This means for example bringing in the surrounding lines, but more importantly for LSP and Treesitter, entire surrounding functions for example.
This feature goes beyond mere bulk editing and towards a future kind of code editing where we don't care so much about what file something is in, but rather what relates to it, and instead of splits can get everything relevant for us brought into the same Metabuffer, in some cases automatically.

In the end this will allow both quicker editing for humans, and reduced lookups and context for LLM agents.

## In practice

- We'll need prompt #commands to perform this. Format: `#exp:expansiontype`.
  - So for example `#exp:fn` to show the full function scope (whether the hit is the actual function definition, or something within the function, the entire function should be hrought in).
  - `#exp:class` for class definition.
  - `#exp:usage` for anywhere the hit is referenced.
  - We need a command to bring in the definition of every _other_ (non-hit) symbol referenced in an expanded hit scope (for example fn) (whether in same file or others), and any places it might be modified (for mutable code). `#exp:env`.

## Implementation

We may need to rethink some things. Perhaps rather than keeping everything in a single results buffer we might need to have another vsplit that shows these things, and indicating where they originate.

The purpose is again to build up (save and reusable) "views" of context often spanning multiple files. Regular development not involving creating many new files but rather editing existing ones could be mostly performed through Metabuffer.

## Prereqs

This requires Treesitter with grammar for the specific language. We should probably just run :TSInstall automatically if any are missing. And note the dep on nvim-treesitter.
