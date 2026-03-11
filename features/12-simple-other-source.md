The first non-file source we'll support will be searching names of files themselves
#file flag in prompt or when invoking Meta will include files in project mode. They will be listed (with their full path) in the hit buffer, with high priority (loaded early). In the info window show their total number of lines as the line number. Info window just shows the icon, lineno (length), glyph, compressed path as usual.
Preview window shows file contents from the top of file.
<CR> on a file hit opens that file from line 1.

Also maybe try it with vimdocs? :O could be a cool mode.
