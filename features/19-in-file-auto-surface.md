This feature has a lot overlapping with 01_3-conceal, and other treesitter things.
We want a mode where the [thing] (fn, class, etc) around cursor gets its context automatically surfaced and displayed. This means referenced globals/class vars, outgoing and incoming calls for a function, for example.

We need to figure out how to do "move around file/hits" in a smart way since we mostly don't want to show the actual surroundings but the relevant things from elsewhere in the file or project. But we still need to be able to see the local surroundings well enough to scroll to them. Maybe the preview window can help there, or a minimap (mini.nvim has one). Or we simply must have multiple splits, showing actual file on left and regions of context on right (plus an info window next to it). One idea is to collapse all the other [functions, ] around a source so we can see more.
-Other possible layout, three panes, normally like 1. callers 2. fn and vars 3. callees.
-Side by side, header left, meta with impl right 

The core idea is that as you change local focus, the rest also updates for wherever you go.
It must be easy to move to somewhere in the shown context and make that the focuspoint, and so navigate around the project (anhd back with <C-o>) always getting relevant stuff displayed.
-Need sortcuts to like move to split 3, focus fn, make that true focus and move that to middle. OR better, fourth split can open and entire thing "slide" as far away splits get minimizedish. <C-i>/<C-o> but auto by split kinda.

Both treesitter (for figuring out what kinda block focus is in) and LSP will be needed for this

Agents will need a "just bring me the context" mode where a tool simply dumps what would've been shown on screen, with file markings of course. And a "expand context from here" action that grabs stuff from ever more outwards.
- This could be used to drive an nvim instance next to claude/codex and "show what it sees". The fact that only selected stuff gets output should mean it's more than a cool looking blur of lines, as well.

With nice way to build up a buffer of context, agent can edit just those regions in the corresponding "file-based metabuffer" that agent actually can see.

Also if having agent drive nvim view, can do reverse and manually metabuffer up good context (mostly automatically, still) and send it back over.
Especially Gemini just shits me with its stupid 50 line greps over and over to find all it needs.
