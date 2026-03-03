# metabuffer

Fennel-first port of `metabuffer.nvim`, structured for an `nfnl` workflow.

## nfnl Layout

This repository follows the `nfnl` plugin pattern:

- Source of truth: `fnl/`
- Generated runtime output: `lua/` and `plugin/`
- nfnl config: `.nfnl.fnl`

Key entrypoints:

- Source module: `fnl/metabuffer/init.fnl`
- Source plugin bootstrap: `fnl/plugin/metabuffer.fnl`
- Generated module: `lua/metabuffer/init.lua`
- Generated plugin bootstrap: `plugin/metabuffer.lua`

## Build / Compile

Recommended workflow:

- Use `nfnl` in Neovim to compile on write while editing `fnl/**/*.fnl`.
- Run `:NfnlCompileAllFiles` for a full project compile.
- Commit generated Lua (`lua/` + `plugin/`) so users do not need `nfnl` to run this plugin.

Utility scripts:

```sh
# Embed a namespaced copy of nfnl under lua/metabuffer/nfnl
./script/nfnl

# One-shot project compile via headless Neovim + embedded nfnl
./scripts/compile-fennel.sh

# Continuous Fennel lint watch (fast syntax/parens feedback)
./scripts/watch-fennel.sh

# Lint + full compile watch (heavier, end-to-end)
./scripts/watch-fennel.sh --compile
```

Repository hygiene (aligned with nfnl recommendations):

- `.ignore` hides generated Lua from search tools.
- `.gitattributes` marks generated and vendored Lua for GitHub linguist.

## Commands

- `:Meta[!] [query]` (`!` starts repo-wide source mode)
- `:MetaResume [query]`
- `:MetaCursorWord`
- `:MetaResumeCursorWord`
- `:MetaSync [query]`
- `:MetaPush`

Runtime toggles while Meta is active:

- `<C-b>` toggle repo-wide source mode (shows floating source info window on the right)

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
