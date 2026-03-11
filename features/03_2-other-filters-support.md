# We might want to filter by arbitrary ways not exactly text.

## For example, showing all lines with a gitgutter edit sign.

- This should be doable with #function arguments.
- #file should enable matching of filenames (showing in results buffer) as such:

The first non-file source we'll support will be searching names of files themselves
#file flag in prompt or when invoking Meta will include files in project mode. They will be listed (with their full path) in the hit buffer, with high priority (loaded early). In the info window show their total number of lines as the line number. Info window just shows the icon, lineno (length), glyph, compressed path as usual.
Preview window shows file contents from the top of file.
<CR> on a file hit opens that file from line 1.

Once "writing" results buffer edits back is implemented, editing a file hit should move that file.

## All these function calls will also mean we probably want to work on our prompt functionality in general.

- So if #file is on a line, only the other text on that line should be impacting the file filtering, not the entire prompt. Only the token following #file should search files.
- If at the end of a line, for the single token/identifier (or quoted one) after #file, same thing.

## Other ideas

- Also maybe try it with vimdocs? :O could be a cool mode. `#doc` would bring in :h full text search and filtering.
