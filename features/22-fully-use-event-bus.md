# Event bus

We have migrated plugin compatibility stuff, and a few other things, to use our event bus.
We now want to fully move towards utilizing this, mainly so that nvim side effects aren't sprinkled all over the codebase.
First we isolated compat, now let's do the rest. All autocmds should simply spawn events instead of doing things directly. Similarly, our own lifecycle (load finished, for example) should spawn events, not directly side-effect.
Example: when streaming line candidates, finishing would emit an event rather than do things on its own. Another module or modules, registered for that event, would handle what it actually results in.
Example: currently any number of things might cause refreshes (local or complete), and how they are handled is spread out all over the codebase and can be inconsistent. Moving to consolidated events (with args) and handlers means we can centralize update logic much better, as well as easily log what events cause what effects (see what handlers are registered, what order they run, etc).

We might need more event types, figure it out and make sure there's a full spec available showing all types and args.

Many modules can hence move from interacting directly with neovim and having a bunch of side-effecting functions manually triggered, to simply returning a config map that gets registered with the event bus.

This should also mean less passing around of session, deps etc all over the codebase, because they can be injected by the event runner, DI style. Meaning that which runs on a given event can also declare exactly what it depends on, and have it injected (along with args from the event trigger etc)

While doing this pass, also try to minimize the unnecessary constant creating of locals simply pointing somewhere into a map unless it gets heavily used and saves a lot of space. If only a few usages, access directly instead.

Also focus on where source types, flags etc are referenced directly around the codebase. Things like highlighting rules and similar should also be done fully isolated inside the definition and applied automatically, not hardcoded all over the place.
