This feature has a lot overlapping with 01_3-conceal, and other treesitter things.
We want a mode where the [thing] (fn, class, etc) around cursor gets its context automatically surfaced and displayed. This means referenced globals/class vars, outgoing and incoming calls for a function, for example.

We need to figure out how to do "move around file/hits" in a smart way since we mostly don't want to show the actual surroundings but the relevant things from elsewhere in the file or project. But we still need to be able to see the local surroundings well enough to scroll to them. Maybe the preview window can help there, or a minimap (mini.nvim has one). Or we simply must have multiple splits, showing actual file on left and context on right (plus an info window next to it). One idea is to collapse all the other [functions, ] around a source so we can see more.
The core idea is that as you change local focus, the rest also updates for wherever you go.
It must be easy to move to somewhere in the shown context and make that the focuspoint, and so navigate around the project (and back with <C-o>) always getting relevant stuff displayed.

Both treesitter (for figuring out what kinda block focus is in) and LSP will be needed for this.

Agents will need a "just bring me the context" mode where a tool simply dumps what would've been shown on screen, with file markings of course. And a "expand context from here" action that grabs stuff from ever more outwards.
- This could be used to drive an nvim instance next to claude/codex and "show what it sees". The fact that only selected stuff gets output should mean it's more than a cool looking blur of lines, as well.
