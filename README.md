# metabuffer

Fennel-first port of `metabuffer.nvim`, structured for an `nfnl` workflow.

## nfnl Layout

This repository now follows the `nfnl` plugin pattern:

- Source of truth: `fnl/`
- Generated runtime output: `lua/` and `plugin/`
- nfnl config: `.nfnl.fnl`

Key entrypoints:

- Source module: `fnl/metabuffer/init.fnl`
- Source plugin bootstrap: `fnl/plugin/metabuffer.fnl`
- Generated module: `lua/metabuffer/init.lua`
- Generated plugin bootstrap: `plugin/metabuffer.lua`

## Build / Compile

`fennel` is used to compile all Fennel sources:

```sh
./scripts/compile-fennel.sh
```

The script compiles:

- `fnl/plugin/*.fnl -> plugin/*.lua`
- `fnl/**/*.fnl -> lua/**/*.lua`

## Commands

- `:Meta[!] [query]`
- `:MetaResume [query]`
- `:MetaCursorWord`
- `:MetaResumeCursorWord`
- `:MetaSync [query]`
- `:MetaPush`

## Module Structure

The port mirrors the original Python module breakdown:

- `fnl/metabuffer/router.fnl`
- `fnl/metabuffer/meta.fnl`
- `fnl/metabuffer/action.fnl`
- `fnl/metabuffer/modeindexer.fnl`
- `fnl/metabuffer/handle.fnl`
- `fnl/metabuffer/util.fnl`
- `fnl/metabuffer/sign.fnl`
- `fnl/metabuffer/buffer/{base,metabuffer,regular,ui}.fnl`
- `fnl/metabuffer/window/{base,metawindow,floating,prompt}.fnl`
- `fnl/metabuffer/matcher/{base,all,fuzzy,regex,attrib,generic,range,textobj}.fnl`
- `fnl/metabuffer/prompt/{prompt,action,keymap,key,keystroke,caret,history,digraph,util}.fnl`
