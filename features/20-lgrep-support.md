# lgrep support

[lgrep](https://github.com/dennisonbertram/lgrep) is a new tool for embedding-driven contextual search of codebases.
It indexes a repo and allows many different lookups.

Output of `lgrep --help`:

```help
Usage: lgrep [options] [command]

Local semantic search CLI - privacy-first, mixedbread.ai quality without the
cloud

Options:
  -V, --version                         output the version number
  -h, --help                            display help for command

Commands:
  setup [options]                       Install Ollama and pull required models
  index [options] <path>                Index files in a directory for semantic search
  search [options] [query]              Search indexed content with code intelligence
  list [options]                        List all indexes
  graph [options]                       Open a local web UI to visualize dependency/call graphs
  delete [options] <name>               Delete an index
  clean [options]                       Clean up zombie, failed, and stale indexes
  config [options] [key] [value]        Get or set configuration values
  analyze [options] <path>              Analyze code structure (symbols, dependencies, calls)
  context [options] <task>              Build context for a task (for LLM consumption)
  watch [options] <path>                Start watching a directory for changes
  stop [options] <name>                 Stop watching an index
  callers [options] <symbol>            Show all locations that call a given function/method
  deps [options] <module>               Show what modules import/depend on a given module
  impact [options] <symbol>             Show the blast radius if you change a function (direct callers + transitive impact)
  dead [options]                        List functions/methods with zero callers
  similar [options]                     Find groups of symbols with similar code
  cycles [options]                      Detect circular import/dependency chains
  unused-exports [options]              List exports that are never imported
  breaking [options]                    Check for calls that may break when signature changes
  rename [options] <oldName> <newName>  Preview the impact of renaming a symbol
  intent [options] <prompt>             Interpret NL intent and run the appropriate lgrep command
  install [options]                     Install lgrep integration with Claude Code
  install-mcp [options]                 Install lgrep as an MCP server for Claude Code
  doctor [options]                      Check lgrep health, configuration, and indexing status
  stats [options]                       Show index statistics (files, chunks, symbols, etc.)
  logs [options]                        View watcher daemon logs
  symbols [options] [query]             Quick symbol lookup by name
  explain [options] <target>            AI-powered explanation of a file or symbol
  daemon                                Manage query daemon servers (keeps index in memory for instant queries)
  help [command]                        display help for command
```

## Usecase

* We want to be able to use this in Metabuffer project mode.
* This will require implementing a new source-type, but since we get both filename and starting line number for the hits, this should be simple.
* usage through `#l`. Since we probably want to further filter the hits, anything except for the token or quotes string after `#l` should be AND as usual. 
* Also probably want a setting or flag to enable it by default as well.


example output of `lgrep search setup -j`:

```json
{
   "count" : 10,
   "query" : "setup",
   "results" : [
      {
         "chunk" : "ths true} (configure-fennel-ls paths)\n      _ (do (set options.log-level :error) ; we want errors to be visible in the REPL\n            (setup-paths paths)\n            (dofile fennel-arg)))))\n\n(main)",
         "file" : "scripts/deps",
         "line" : 1683,
         "score" : 0.442629396915436
      },
      {
         "chunk" : "ource-set-rebuild! schedule-source-set-rebuild!\n             :apply-minimal-source-set! apply-minimal-source-set!\n             :schedule-project-bootstrap! schedule-project-bootstrap!}]\n    api)))\n\nM",
         "file" : "fnl/metabuffer/project/source.fnl",
         "line" : 679,
         "score" : 0.473742246627808
      },
      {
         "chunk" : "ank_to_register\" _yank_to_register]\n    [\"prompt:yank_to_default_register\" _yank_to_default_register]\n    [\"prompt:insert_special\" _insert_special]\n    [\"prompt:insert_digraph\" _insert_digraph] ])\n\nM",
         "file" : "fnl/metabuffer/prompt/action.fnl",
         "line" : 277,
         "score" : 0.46305388212204
      },
      {
         "chunk" : "on_21(existing)\n        else\n        end\n        local origin_win = vim.api.nvim_get_current_win()\n        local origin_buf = source_buf\n        local source_view = vim.fn.winsaveview()\n        local _\n        source_view[\"_meta_win_height\"] = vim.api.nvim_win_get_height(origin_win)\n        _ = nil\n        local condition = session_view[\"setup-state\"](query1, mode, source_view)\n        local _0\n        condition[\"selected-index\"] = project_start_selected_index(project_mode, mode, source_view, condition)\n        _0 = nil\n        local curr = meta_mod.new(vim, condition)\n        curr[\"project-mode\"] = (project_mode or false)\n        router_util_mod[\"ensure-source-refs!\"](curr)\n        curr.buf[\"keep-modifiable\"] = true\n        do\n          local bo = vim.bo[curr.buf.buffer]\n          bo[\"buftype\"] = \"acwrite\"\n          bo[\"modifiable\"] = true\n          bo[\"readonly\"] = false\n          bo[\"bufhidden\"] = \"hide\"\n        end\n        pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, \"meta_manual_edit_active\", false)\n        pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, \"meta_internal_render\", false)\n        pcall(curr.buf.render)\n        local initial_lines\n        if (prompt_query0 and (prompt_query0 ~= \"\")) then\n          initial_lines = vim.split(prompt_query0, \"\\n\", {plain = true})\n        else\n          initial_lines = {\"\"}\n        end\n        local prompt_animates_3f = (ui_animation.enabled and not (false == ui_animation_prompt.enabled))\n        local animation_settings = {enabled = not (false == ui_animation.enabled), backend = (ui_animation.backend or \"native\"), [\"time-scale\"] = (ui_animation[\"time-scale\"] or 1), prompt = {enabled = not (false == ui_animation_prompt.enabled), ms = ui_animation_prompt.ms, [\"time-scale\"] = (ui_animation_prompt[\"time-scale\"] or 1), backend = (ui_animation_prompt.backend or \"native\")}, preview = {enabled = not (false == ui_animation_preview.enabled), ms = ui_animation_preview.ms, [\"time-scale\"] = (ui_animation_preview[\"time-scale\"]",
         "file" : "lua/metabuffer/router/session.lua",
         "line" : 596,
         "score" : 0.475140631198883
      },
      {
         "chunk" : "mpt))\n    (set router.main-keymaps (. keymaps :main))\n    (set router.prompt-fallback-keymaps (. keymaps :prompt_fallback))\n    (set router.dep-dir-names (. options :dep_dir_names))\n    resolved))\n\nM",
         "file" : "fnl/metabuffer/config.fnl",
         "line" : 425,
         "score" : 0.475091338157654
      },
      {
         "chunk" : "#!/usr/bin/env sh\nset -eu\n\nROOT_DIR=$(CDPATH= cd -- \"$(dirname -- \"$0\")/..\" && pwd)\ncd \"$ROOT_DIR\"\n\nnvim --headless -u NONE -n -i NONE \\\n  --cmd \"set runtimepath^=.\" \\\n  -c \"lua \\\nlocal ok, err = pcall(function() \\\n  require('metabuffer').setup() \\\n  vim.cmd('enew') \\\n  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma'}) \\\n  require('metabuffer.router').entry_start('', true) \\\n  require('metabuffer.router').finish('cancel', vim.api.nvim_get_current_buf()) \\\nend) \\\nif not ok then \\\n  vim.api.nvim_err_writeln(err) \\\n  vim.cmd('cq') \\\nend\" \\\n  -c \"qa!\"\n\n",
         "file" : "scripts/smoke-meta.sh",
         "line" : 1,
         "score" : 0.467417597770691
      },
      {
         "chunk" : "-- [nfnl] fnl/plugin/metabuffer.fnl\nif (vim.g.loaded_metabuffer == 1) then\n  return nil\nelse\n  vim.g.loaded_metabuffer = 1\n  if (vim.g.fennel_lua_version == nil) then\n    vim.g[\"fennel_lua_version\"] = \"5.1\"\n  else\n  end\n  if (vim.g.fennel_use_luajit == nil) then\n    if jit then\n      vim.g[\"fennel_use_luajit\"] = 1\n    else\n      vim.g[\"fennel_use_luajit\"] = 0\n    end\n  else\n  end\n  local m = require(\"metabuffer\")\n  return m.setup()\nend\n",
         "file" : "plugin/metabuffer.lua",
         "line" : 1,
         "score" : 0.476839244365692
      },
      {
         "chunk" : "alse true) false (float-config origin-win start-height))\n                (open-split-win! origin-win local-layout? start-height))\n        self (base.new nvim win [] {})]\n      (if floating?\n          (pcall vim.api.nvim_win_set_config win (float-config origin-win start-height))\n          (pcall vim.api.nvim_win_set_height win start-height))\n      (let [buf (prompt-buffer! win)]\n      ;; Common nvim-cmp convention: buffer-local opt-out.\n        (let [b (. vim.b buf)]\n          (set (. b :cmp_enabled) false)\n          (prompt-window-opts! win))\n        (set self.buffer buf)\n        (set self.floating? floating?)\n        self)))\n\n(fn M.handoff-to-split!\n  [nvim prompt-win opts]\n  (let [cfg (or opts {})\n        origin-win cfg.origin-win\n        local-layout? (if (= cfg.window-local-layout nil) true cfg.window-local-layout)\n        height (math.max 1 (or cfg.height 1))\n        old-win (. prompt-win :window)\n        buf (. prompt-win :buffer)\n        saved-view (and origin-win\n                        (vim.api.nvim_win_is_valid origin-win)\n                        (vim.api.nvim_win_call origin-win (fn [] (vim.fn.winsaveview))))\n        split-win (open-split-win! origin-win local-layout? height)\n        old-buf (and split-win\n                     (vim.api.nvim_win_is_valid split-win)\n                     (vim.api.nvim_win_get_buf split-win))]\n    (pcall vim.api.nvim_win_set_buf split-win buf)\n    (wipe-replaced-split-buffer! old-buf)\n    (pcall vim.api.nvim_win_set_height split-win height)\n    (prompt-window-opts! split-win)\n    (when (and origin-win\n               saved-view\n               (vim.api.nvim_win_is_valid origin-win))\n      (vim.api.nvim_win_call\n        origin-win\n        (fn []\n          (pcall vim.fn.winrestview saved-view))))\n    (when (and old-win (vim.api.nvim_win_is_valid old-win))\n      (pcall vim.api.nvim_win_close old-win true))\n    (let [self (base.new nvim split-win [] {})]\n      (set self.buffer buf)\n      (set self.floating? false)\n      self)))\n\nM",
         "file" : "fnl/metabuffer/window/prompt.fnl",
         "line" : 99,
         "score" : 0.477014660835266
      },
      {
         "chunk" : "nt.match \"background\"))\n                   (ensure-defaults-and-highlights! last-setup-opts)\n                   (pcall vim.cmd \"redrawstatus\")))}))\n\n(fn ensure-command\n  [name callback opts]\n  (pcall vim.api.nvim_del_user_command name)\n  (vim.api.nvim_create_user_command name callback opts))\n\n(fn plugin-root\n  []\n  (let [src (. (debug.getinfo 1 \"S\") :source)\n        path (if (vim.startswith src \"@\") (string.sub src 2) src)]\n    ;; .../lua/metabuffer/init.lua -> plugin root\n    (vim.fn.fnamemodify path \":p:h:h:h\")))\n\n(fn clear-module-cache\n  []\n  (each [k _ (pairs package.loaded)]\n    (when (or (= k \"metabuffer\") (vim.startswith k \"metabuffer.\"))\n      (set (. package.loaded k) nil))))\n\n(fn clear-plugin-loaded-flags!\n  []\n  ;; Keep compatibility with older bootstrap guards.\n  (set vim.g.loaded_metabuffer nil)\n  (set vim.g.meta_loaded nil))\n\n(fn source-plugin-bootstrap!\n  []\n  (let [root (plugin-root)\n        file (.. root \"/plugin/metabuffer.lua\")]\n    (if (= 1 (vim.fn.filereadable file))\n        (vim.cmd (.. \"silent source \" (vim.fn.fnameescape file)))\n        (error (.. \"plugin bootstrap not found: \" file)))))\n\n(fn maybe-compile!\n  []\n  (let [root (plugin-root)\n        script (.. root \"/scripts/compile-fennel.sh\")]\n    (if (= 1 (vim.fn.filereadable script))\n        (let [out (vim.fn.system [\"sh\" script])]\n          (if (= vim.v.shell_error 0)\n              true\n              (error (.. \"compile failed:\\n\" out))))\n        (error (.. \"compile script not found: \" script)))))\n\n(fn M.reload\n  [opts]\n  \"Public API: M.reload.\"\n  (let [cfg (or opts {})\n        do-compile (and cfg.compile true)]\n    (when do-compile\n      (maybe-compile!))\n    (clear-module-cache)\n    (clear-plugin-loaded-flags!)\n    (source-plugin-bootstrap!)\n    (vim.notify (if do-compile \"[metabuffer] reloaded (compiled)\" \"[metabuffer] reloaded\") vim.log.levels.INFO)\n    true))\n\n(fn M.setup\n  [opts]\n  \"Public API: M.setup.\"\n  (set last-setup-opts opts)\n  (router.configure opts)\n  (ensure-defaults-and-highlights!",
         "file" : "fnl/metabuffer/init.fnl",
         "line" : 526,
         "score" : 0.479025840759277
      },
      {
         "chunk" : "a_check() {\n  echo \"[metabuffer-checks] headless: nvim setup + Meta + Meta!\"\n  nvim --headless -u NONE -n -i NONE \\\n    --cmd \"set runtimepath^=.\" \\\n    -c \"lua \\\nlocal ok, err = pcall(function() \\\n  require('metabuffer').setup() \\\n  local r = require('metabuffer.router') \\\n  vim.cmd('enew') \\\n  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma', 'Meta status'}) \\\n  r.entry_start('', false) \\\n  r.finish('cancel', vim.api.nvim_get_current_buf()) \\\n  r.entry_start('', true) \\\n  r.finish('cancel', vim.api.nvim_get_current_buf()) \\\nend) \\\nif not ok then \\\n  vim.api.nvim_err_writeln(err) \\\n  vim.cmd('cq') \\\nend\" \\\n    -c \"qa!\"\n}\n\nrun_basic_profile() {\n  local profile_dir\n  profile_dir=\"$target_dir/.cache/metabuffer-checks\"\n  mkdir -p \"$profile_dir\"\n\n  echo \"[metabuffer-checks] profile: startup -> $profile_dir/startuptime.log\"\n  nvim --headless -u NONE -n -i NONE --startuptime \"$profile_dir/startuptime.log\" +qa >/dev/null 2>&1\n\n  echo \"[metabuffer-checks] profile: Meta timings -> $profile_dir/meta-profile.log\"\n  PROFILE_OUT=\"$profile_dir/meta-profile.log\" \\\n    nvim --headless -u NONE -n -i NONE \\\n      --cmd \"set runtimepath^=.\" \\\n      -c \"lua \\\nlocal out = os.getenv('PROFILE_OUT') \\\nlocal function ms_from(start_ns) \\\n  return ((vim.loop.hrtime() - start_ns) / 1000000.0) \\\nend \\\nlocal lines = {} \\\nlocal ok, err = pcall(function() \\\n  local t0 = vim.loop.hrtime() \\\n  require('metabuffer').setup() \\\n  table.insert(lines, string.format('setup_ms=%.3f', ms_from(t0))) \\\n  local r = require('metabuffer.router') \\\n  vim.cmd('enew') \\\n  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha', 'beta', 'gamma', 'Meta status'}) \\\n  local t1 = vim.loop.hrtime() \\\n  r.entry_start('', false) \\\n  r.finish('cancel', vim.api.nvim_get_current_buf()) \\\n  table.insert(lines, string.format('meta_ms=%.3f', ms_from(t1))) \\\n  local t2 = vim.loop.hrtime() \\\n  r.entry_start('', true) \\\n  r.finish('cancel', vim.api.nvim_get_current_buf()) \\\n  table.insert(lines, string.format('meta_bang_ms=%.3f', ms_from(t2))) \\\nend) \\\nif not ok then \\\n  table.insert(lines, 'error=' ..",
         "file" : "skills/metabuffer-checks/scripts/run-checks.sh",
         "line" : 75,
         "score" : 0.464664578437805
      }
   ]
}
```

Help for `lgrep search`:
```help
Usage: lgrep search [options] [query]

Search indexed content with code intelligence

Options:
  -i, --index <name>        Index to search (auto-detected from current directory if not specified)
  -l, --limit <number>      Maximum results (default: "10")
  -d, --diversity <lambda>  Diversity parameter (0.0=max diversity, 1.0=pure relevance) (default: "0.7")
  --usages <symbol>         Find usages of a symbol
  --definition <symbol>     Find symbol definition
  --type <kind>             Filter by symbol type (function, class, interface, etc.)
  -j, --json                Output as JSON
  -h, --help                display help for command```

We likely want to fetch more than 10 by default, and order them by score, but also group by file.

Calculate the line numbers from the starting "line" value, then count instances of `\n`.

Search is very fast (that's the point of having indexes) but we still want a more loose debounce so that searches don't happen prematurely.

We need to support `#l` in both `:Meta` and `:Meta!`, and once invoked cursorline for results buffer should jump to start of first hit.


## Presentation

* Info window lines similar to regular project mode, showing the lineno and filepath.
- Searched-for word might not appear in any given result, but if it does should be highlighted in a special color, not like the regular hit highlights. Also mirror this in the prompt (`#l setup` -> both use lgrep hit highlight)
- Preview should work like normally, showing the full context from the original source.
- `#l:u` should show usages (`--usages`), `#l:d` definition (`--definition`), no hits if not a symbol
