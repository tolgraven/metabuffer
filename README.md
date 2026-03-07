# metabuffer

Fennel-first port of `metabuffer.nvim`, structured for an `nfnl` workflow.

## nfnl Layout

This repository follows the `nfnl` plugin pattern:

- Source of truth: `fnl/`
- Generated runtime output: `lua/` and `plugin/`
- nfnl config: `.nfnl.fnl`

Cljlib integration for Clojure-style macros:

- Macro entrypoint vendored at `fnl/io/gitlab/andreyorst/cljlib/core/init.fnlm`
- Project modules import selected cljlib macros (for example `when-let` / `if-let`) via:
  `(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)`

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

## Prompt Niceties

The default prompt supports shell/emacs-style editing and history shortcuts.

Insert-mode edit keys:

- `<C-a>` move to line start
- `<C-e>` move to line end
- `<C-u>` delete from line start to cursor
- `<C-k>` delete from cursor to line end
- `<C-y>` yank previously killed prompt text

History insertion shorthands (insert + normal):

- `!!` insert latest history entry at cursor
- `!$` insert last token from latest history entry
- `!^!` insert latest history entry except first token

Token operators:

- Leading `!` negates a token in `all` matcher mode
- `^` and `$` anchors are supported per token
- In insert mode, `<LocalLeader>1` and `<LocalLeader>!` toggle negation of the token at cursor
- In the result window (normal mode), `!` appends `!<cword>` into the prompt

History/searchback:

- `<C-r>` opens floating history searchback browser
- Typing in prompt filters browser items live
- `<Up>/<Down>` move browser selection while open
- `<CR>` applies selected history/saved entry into prompt
- `<Esc>` closes browser first; pressing again closes Meta
- Session history is isolated; merge persisted history explicitly with:
  - prompt directive `#history` (consumed)
  - `<LocalLeader>h`

Saved prompts:

- `#save:tag` saves current prompt text under `tag` (directive is consumed)
- `##tag` restores saved prompt inline
- `##` opens saved-prompt browser

Persistence:

- Prompt history and saved tags are persisted to:
  - `stdpath("data")/metabuffer_prompt_history.json`

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
