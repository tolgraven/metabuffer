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
