;;; Compat providers — builtin third-party plugin shims.
;;;
;;; Returns a sequential list of provider modules for the event bus.
;;; Registration is performed explicitly by the caller via events.load-providers!.
;;;
;;; Each provider module returns {:name str :domain str :events {:<event> <spec>}}.

(local airline        (require :metabuffer.compat.airline))
(local buffer-plugins (require :metabuffer.compat.buffer_plugins))
(local conjure        (require :metabuffer.compat.conjure))
(local cmp            (require :metabuffer.compat.cmp))
(local hlsearch       (require :metabuffer.compat.hlsearch))
(local rainbow        (require :metabuffer.compat.rainbow))

[airline buffer-plugins conjure cmp hlsearch rainbow]
