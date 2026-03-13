# Better runner for :s/ operations

This is a thing we can easily add support for thanks to our in-buffer mode of operation.
- When starting a line with `:s/`, this should allow substitute over the hit buffer. Of course one could simply navigate there and do regular `:s/`, but that's not as nicely done.
- This obviously enables regex mode for everything that follows.
- We want live preview, first while writing the regex (matches show), then when substituting (show what will be after <CR>)
- <CR> on such a line should not close metabuffer, just invoke that line.
- Capture groups need to each get a different color and be marked through underline (and possibly dim background) highlighting.


