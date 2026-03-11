We want the plugin to be configurable with the normal lua workflow, not vim.g.
Meaning, we want to be able to put `opts` in the map given to `setup()`.
Expose all the defaults, keymaps and options here, and keep track of things by similar maps of option state.
