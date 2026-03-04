We might want to filter by arbitrary ways not exactly text.
For example, showing all lines with a gitgutter edit sign.
This should be doable with #function arguments.
#file should enable matching of filenames.

All these function calls will also mean we probably want to work on our prompt functionality in general. So if #file is on a line, only the other text on that line should be impacting the file filtering, not the entire prompt. If at the end of a line, or a single identifier (or quoted one) after #file, same thing.
