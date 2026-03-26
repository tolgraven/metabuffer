;;; Compat module — registers third-party plugin shims into the event bus.
;;;
;;; This module is a side-effect-only loader.  Requiring it ensures all
;;; builtin compat handlers (airline, nvim-cmp, hlsearch, etc.) are
;;; registered in the event bus before any session starts.
;;;
;;; The event bus itself lives at metabuffer.events.
;;; Compat sub-modules live under metabuffer.compat.*.

(local events (require :metabuffer.events))

(local airline       (require :metabuffer.compat.airline))
(local buffer-plugins (require :metabuffer.compat.buffer_plugins))
(local cmp           (require :metabuffer.compat.cmp))
(local hlsearch      (require :metabuffer.compat.hlsearch))
(local rainbow       (require :metabuffer.compat.rainbow))

(each [_ mod (ipairs [airline buffer-plugins cmp hlsearch rainbow])]
  (events.register! mod))

{}
