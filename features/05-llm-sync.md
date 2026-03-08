This is an important feature that will later be extended so the plugin gets usable by LLM agents as well. But to begin we will focus on helping developers follow along with what is being done by their agents.
This means agents (both primary and sub) can drive our viewport(s), Meta prompts etc, so what we can see what they are working on.
This feature relies heavily on very good "hit expansion" functionality, so that an agent can easily take us to where edits are happening and show them in full.
We will also need some kind of specific index where agents store basic info about their edits.

This will all be done by driving nvim over a socket.

For example:
```
 Explored
  └ Search
apply-source-syntax-regions|schedule-source-syntax-refresh|sync|scroll-main|update-info-window|
           render in router.fnl
    Read router.fnl
```
could put this search into Meta! and show what you see

This means we deliver results concurrently to the agent while driving our UI.

Other context-pull wins:
- Some command to automatically bring into metabuffer the docstring, source, other repo mentions, sub-agent web lookup of any function referenced in the function we've pulled in from first getting it as a result.
- General other "follow the symbols" paths where you can just go "+" and broaden the scope of context for your hit(s)
  - Very important that we allow both piece-by-piece (char by char when filtering, smoothly expanding context when pulling that in) interactive way of things for humans, and "straight to what I say" headless intermediate context minimizing modes.
    - Best of all if can make agents separately drive a more "zooming in" / "out" workflow on the side, while themselves working by going straight to exactly what they want.
- Plugin, but especially MCP should allow things like "context of function" that's essentially a bolted together layer above LSP level that does what it says.
