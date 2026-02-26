;; Fennel source mirror for the Lua runtime.
;; This initial port keeps runtime logic in lua/metabuffer/init.lua so the plugin
;; is directly loadable by Neovim without requiring a Fennel compiler at startup.

(local M {})

(fn M.setup []
  ((require :metabuffer).setup))

(fn M.start [opts]
  ((require :metabuffer).start opts))

(fn M.resume [opts]
  ((require :metabuffer).resume opts))

(fn M.sync [query]
  ((require :metabuffer).sync query))

(fn M.push []
  ((require :metabuffer).push))

M
