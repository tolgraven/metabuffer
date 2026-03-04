We want to have nice syntax highlighting for the prompt buffer.
Including but not limited to:
- #flags and #functions being highlighted
- Regex highlighting for that mode, showing the various types of chars in different colors (one for $ and ^, one for backticked stuff like \w, etc)
  - Use treesitter regex for this
- | pipe (which should mean OR) and & etc highlighted

We also want to be able to type a filter query, then a new line (or the same one) with a :s/ substitute and press <CR> to run that.
