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
  ui = {
    animation = {
      enabled = true,
      backend = "native",
      time_scale = 1.0,
      loading_indicator = true,
      prompt = { enabled = true, time_scale = 1.0 },
      preview = { enabled = true, time_scale = 1.0 },
      info = { enabled = true, time_scale = 1.0 },
      loading = { enabled = true, time_scale = 1.0 },
      scroll = { enabled = true, time_scale = 1.0, backend = "native" },
    },
  },
  keymaps = {
    prompt = {
      { { "n", "i" }, "<CR>", "accept" },
      { "n", "<Esc>", "cancel" },
      { "n", "<C-p>", "move-selection", -1 },
      { "n", "<C-n>", "move-selection", 1 },
      { "i", "<C-p>", "move-selection", -1 },
      { "i", "<C-n>", "move-selection", 1 },
      { "n", "<C-k>", "move-selection", -1 },
      { "n", "<C-j>", "move-selection", 1 },
      { "i", "<C-k>", "move-selection", -1 },
      { "i", "<C-j>", "move-selection", 1 },
      { "i", "<C-a>", "prompt-home" },
      { "i", "<C-e>", "prompt-end" },
      { "i", "<C-u>", "prompt-kill-backward" },
      { "i", "<C-y>", "prompt-yank" },
      { "i", "<Up>", "history-or-move", 1 },
      { "i", "<Down>", "history-or-move", -1 },
      { "n", "<Up>", "history-or-move", 1 },
      { "n", "<Down>", "history-or-move", -1 },
      { "i", "!!", "insert-last-prompt" },
      { "n", "!!", "insert-last-prompt" },
      { "i", "!$", "insert-last-token" },
      { "n", "!$", "insert-last-token" },
      { "i", "!^!", "insert-last-tail" },
      { "n", "!^!", "insert-last-tail" },
      { "i", "<LocalLeader>1", "negate-current-token" },
      { "i", "<LocalLeader>!", "negate-current-token" },
      { "n", "<LocalLeader>h", "merge-history" },
      { "i", "<LocalLeader>h", "merge-history" },
      { "i", "<C-r>", "history-searchback" },
      { { "n", "i" }, "<C-^>", "switch-mode", "matcher" },
      { { "n", "i" }, "<C-6>", "switch-mode", "matcher" },
      { { "n", "i" }, "<C-_>", "switch-mode", "case" },
      { { "n", "i" }, "<C-/>", "switch-mode", "case" },
      { { "n", "i" }, "<C-?>", "switch-mode", "case" },
      { { "n", "i" }, "<C-->", "switch-mode", "case" },
      { { "n", "i" }, "<C-o>", "switch-mode", "case" },
      { { "n", "i" }, "<C-s>", "switch-mode", "syntax" },
      { "n", "<C-g>", "toggle-scan-option", "ignored" },
      { "n", "<C-l>", "toggle-scan-option", "deps" },
      { { "n", "i" }, "<C-d>", "scroll-main", "half-down" },
      { "n", "<C-u>", "scroll-main", "half-up" },
      { { "n", "i" }, "<C-f>", "scroll-main", "page-down" },
      { { "n", "i" }, "<C-b>", "scroll-main", "page-up" },
      { { "n", "i" }, "<C-t>", "toggle-project-mode" },
    },
    main = {
      { "n", "!", "exclude-symbol-under-cursor" },
      { "n", "<CR>", "accept-main" },
      { "n", "<M-CR>", "insert-symbol-under-cursor" },
      { "n", "<A-CR>", "insert-symbol-under-cursor" },
    },
    prompt_fallback = {
      { "i", "<C-a>", "prompt-home" },
      { "i", "<C-e>", "prompt-end" },
      { "i", "<C-u>", "prompt-kill-backward" },
      { "i", "<C-k>", "move-selection", -1 },
      { "i", "<C-y>", "prompt-yank" },
    },
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

Animation controls:

- `ui.animation.enabled`: master on/off switch for Meta window animations
- `ui.animation.backend`: global animation backend, `"native"` or `"mini"`
- `ui.animation.time_scale`: master speed multiplier
  - `1.0` = normal
  - `0.5` = twice as fast
  - `2.0` = half speed
- Per-animation toggles and speed scales:
  - `ui.animation.prompt.enabled`, `ui.animation.prompt.time_scale`
  - `ui.animation.preview.enabled`, `ui.animation.preview.time_scale`
  - `ui.animation.info.enabled`, `ui.animation.info.time_scale`
  - `ui.animation.loading.enabled`, `ui.animation.loading.time_scale`
  - `ui.animation.scroll.enabled`, `ui.animation.scroll.time_scale`
- `ui.animation.loading_indicator` controls whether the animated prompt footer loading word is shown at all

`ui.animation.backend` defaults to `"native"`. Set it to `"mini"` to let Meta use `mini.animate` where supported. Per-animation backend keys are still accepted as compatibility overrides, but the global backend is now the intended control surface.

Durations are not part of the public setup surface. Meta keeps sensible base timings internally and applies the master/per-animation scales on top.

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

- managed via dependencies in `deps.fnl` and resolved by `.nfnl.fnl` during compilation.
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
./scripts/init-nfnl

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
