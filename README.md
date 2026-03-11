# metabuffer

Interactive buffer/project line filtering for Neovim, with a prompt-first workflow and fast matcher updates.

![metabuffer screenshot](./metabuffer.png)

## User Guide

### Setup

Use normal Lua setup options (no `vim.g` required):

```lua
require("metabuffer").setup({
  options = {
    prompt_update_debounce_ms = 170,
    window_local_layout = true,
    project_lazy_enabled = true,
  },
  keymaps = {
    prompt = nil, -- set full custom prompt keymap table
    main = nil, -- set full custom main/results keymap table
    prompt_fallback = nil, -- optional insert fallback mappings
  },
  ui = {
    prefix = "#",
    syntax_on_init = "buffer",
    highlight_groups = { All = "Title", Fuzzy = "Number", Regex = "Special" },
  },
})
```

Inspect defaults from Lua:

```lua
require("metabuffer").defaults
```

### Commands

- `:Meta[!] [query]` (`!` starts repo-wide source mode)
- `:MetaResume [query]`
- `:MetaCursorWord`
- `:MetaResumeCursorWord`
- `:MetaSync [query]`
- `:MetaPush`

Commandline history shorthands for `[query]`:

- `!!` expands to latest prompt history entry
- `!$` expands to final token from latest prompt history entry
- `!^!` expands to latest prompt history entry without first token

### Runtime Toggles

- `<C-b>` toggle repo-wide source mode (shows floating source info window on the right)

### Prompt Keys

Insert-mode editing:

- `<C-a>` move to line start
- `<C-e>` move to line end
- `<C-u>` delete from line start to cursor
- `<C-k>` move selection up
- `<C-y>` yank previously killed prompt text

History insertion shorthands (insert + normal):

- `!!` insert latest history entry at cursor
- `!$` insert last token from latest history entry
- `!^!` insert latest history entry except first token

Token operators:

- leading `!` negates a token in `all` matcher mode
- `^` and `$` anchors are supported per token
- in insert mode, `<LocalLeader>1` and `<LocalLeader>!` toggle negation of token at cursor
- in the result window (normal mode), `!` appends `!<cword>` into the prompt

History/searchback:

- `<C-r>` opens floating history searchback browser
- typing in prompt filters browser items live
- `<Up>/<Down>` move browser selection while open
- `<CR>` applies selected history/saved entry into prompt
- `<Esc>` closes browser first; pressing again closes Meta
- session history is isolated; merge persisted history with:
  - prompt directive `#history` (consumed)
  - `<LocalLeader>h`

Saved prompts:

- `#save:tag` saves current prompt text under `tag` (directive is consumed)
- `##tag` restores saved prompt inline
- `##` opens saved-prompt browser

Control directives (consumed from prompt):

- bare `#hidden`, `#ignored`, `#deps`, `#prefilter`, `#lazy` toggle current value
- explicit forms force value:
  - `#+hidden` / `#-hidden`
  - `#+ignored` / `#-ignored`
  - `#+deps` / `#-deps`
  - `#+prefilter` / `#-prefilter`
  - `#+lazy` / `#-lazy`
- aliases:
  - `#nohidden`, `#noignored`, `#nodeps`, `#noprefilter`, `#nolazy`
  - `#escape` is equivalent to disabling prefilter

Persistence:

- prompt history and saved tags are persisted to:
  - `stdpath("data")/metabuffer_prompt_history.json`

## Development

Fennel-first port of `metabuffer.nvim`, structured for an `nfnl` workflow.

### nfnl Layout

This repository follows the `nfnl` plugin pattern:

- source of truth: `fnl/`
- generated runtime output: `lua/` and `plugin/`
- nfnl config: `.nfnl.fnl`

Cljlib integration for Clojure-style macros:

- macro entrypoint vendored at `fnl/io/gitlab/andreyorst/cljlib/core/init.fnlm`
- project modules import selected cljlib macros (for example `when-let` / `if-let`) via:
  `(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)`

Key entrypoints:

- source module: `fnl/metabuffer/init.fnl`
- source plugin bootstrap: `fnl/plugin/metabuffer.fnl`
- generated module: `lua/metabuffer/init.lua`
- generated plugin bootstrap: `plugin/metabuffer.lua`

### Build / Compile

Recommended workflow:

- use `nfnl` in Neovim to compile on write while editing `fnl/**/*.fnl`
- run `:NfnlCompileAllFiles` for a full project compile
- commit generated Lua (`lua/` + `plugin/`) so users do not need `nfnl` to run this plugin

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

- `.ignore` hides generated Lua from search tools
- `.gitattributes` marks generated and vendored Lua for GitHub linguist

### Module Structure

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
