(local base (require :metabuffer.buffer.base))
(local M {})

(fn M.new [nvim opts]
  (base.new nvim (or opts {:name "buffer"})))

M
