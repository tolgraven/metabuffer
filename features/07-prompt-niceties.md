# 07 Prompt Niceties

## Scope summary

Implemented prompt usability additions include:

- token negation (`!term`) with prompt highlighting
- quick anchors (`^`, `$`) in `all` matcher
- result-buffer `!` to append `!<cword>`
- inline history shorthands (`!!`, `!$`, `!^!`)
- commandline shorthand expansion in `:Meta[!]`, `:MetaResume`, `:MetaSync`
- insert-mode shell/emacs edit keys (`<C-a>`, `<C-e>`, `<C-u>`, `<C-k>`, `<C-y>`)
- insert-mode token negation toggles (`<LocalLeader>1`, `<LocalLeader>!`)
- floating searchback browser (`<C-r>`) driven by prompt text
- prompt history persistence and saved prompt tags
- consumable prompt directives (`#history`, `#save:tag`, `##`, `##tag`, and scan flags)
- per-token regex handling in `all` matcher with fallback to literal on invalid regex

## Keybinds

Default prompt keybind additions:

- `!!`: insert latest prompt history entry
- `!$`: insert latest history token
- `!^!`: insert latest history entry without first token
- `<C-a>`: line start
- `<C-e>`: line end
- `<C-u>`: kill backward to line start
- `<C-k>`: kill forward to line end
- `<C-y>`: yank killed text
- `<LocalLeader>1`, `<LocalLeader>!`: toggle `!` on current token
- `<C-r>`: open history searchback browser
- `<LocalLeader>h`: merge persisted history into the current session history cache

## Directives

Control directives are consumed from query text once applied:

- `#history`: merge persisted history into this session cache
- `#save:tag`: save current prompt text under `tag`
- `##tag`: restore saved prompt `tag`
- `##`: open saved prompts browser
- `#+deps` / `#-deps` and other `#(+|-)` scan directives

## Behavior details

- `<CR>` accepts selected hit, or applies selected history/saved-browser entry if browser is open.
- `<Esc>` closes browser first (if open), then closes Meta on next cancel.
- Commandline query shorthands are expanded before session startup:
  - `:Meta !!`
  - `:Meta !$`
  - `:Meta !^!`
- Session history remains local unless merged (`#history` / `<LocalLeader>h`).
- Persistent storage file:
  - `stdpath("data")/metabuffer_prompt_history.json`

## Follow-up work

Not implemented in this feature pass:

- full regex treesitter prompt syntax coloring
- `|`/`&` operator-specific prompt highlighting semantics
- prompt `:s/` substitution execution mode
