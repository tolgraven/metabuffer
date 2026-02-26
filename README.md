# metabuffer

Initial port of `metabuffer.nvim` from Python remote-plugin architecture to an in-process Neovim plugin with a Fennel source directory and Lua runtime.

## Status

This is an initial complete port focused on replacing the buggy Python host path while preserving the interactive workflow.

Implemented commands:

- `:Meta[!] [query]`
- `:MetaResume [query]`
- `:MetaCursorWord`
- `:MetaResumeCursorWord`
- `:MetaSync [query]`
- `:MetaPush`

Implemented matcher/case/syntax modes:

- Matchers: `all`, `fuzzy`, `regex`
- Case: `smart`, `ignore`, `normal`
- Syntax: `buffer`, `meta`

## Usage

Run:

```vim
:Meta
```

In the metabuffer:

- First line is query prompt (`# ...`)
- Remaining lines are filtered candidates
- Edit the first line to live-update filter
- `<CR>` accept (jump to source line)
- `<Esc>` cancel (restore original cursor)
- `<C-z>` pause (return to source without accepting)
- `<C-^>` / `<C-6>` switch matcher
- `<C-_>` / `<C-o>` switch case mode
- `<C-s>` switch syntax mode
- `<Tab>` / `<S-Tab>` / `<C-j>` / `<C-k>` navigate selection

Use `:MetaPush` to push edited visible candidate lines back to the source buffer.

## Notes

- This version intentionally avoids Python remote plugins.
- The runtime module is in `lua/metabuffer/init.lua`.
- Fennel source directory is under `fnl/metabuffer/` for continued migration.

## License

MIT
