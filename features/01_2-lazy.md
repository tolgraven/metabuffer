Lazy hits in general.
- First init windows etc, then fill, and stream results if project mode (possibly keep track of likely number of possible lines we might get, and skip streaming if fewer than 10000 or so), don't wait for them all.
- Additional debounce for incoming chunks so doesn't flicker.
- Later chunks come in further down, so doesn't jump.
- Prioritize surrounding sources (files) and already open buffers,they can probably be pulled in right away.
- Don't forget (in case user has started typing or started with text from beginning) to properly filter incoming chunks as well.
- In case of running something like :Meta! [searchterm] we might want to pre-filter to make it less heavy. But should be able to escape pre-filtering (keybind or entering #escape in prompt)
  - This (and re-enabling #hidden, #deps etc) should also stream in.
- Should be able to manually skip this functionality (if running headless for example)
- Also use a cache for this so can be quicker on later loads (remember proper per-file invalidation, so might need a watcher, preferably something already existing)

This is important both for project search performance and later features.
