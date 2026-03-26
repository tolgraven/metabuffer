(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.digit-width-from-max-value
  [max-value]
  "Min width 3 so project-mode doesn't jump when a 3-digit lnum first appears."
  (math.max 3 (# (tostring (math.max 1 (or max-value 1))))))

(fn M.digit-width-from-max-len
  [max-len]
  "Min width 3 to prevent column jump on first 3-digit line number."
  (math.max 3 (or max-len 1)))

(fn M.field-width-from-max-value
  [max-value]
  (+ (M.digit-width-from-max-value max-value) 1))

(fn M.lnum-cell
  [lnum digit-width]
  (let [s (tostring lnum)
        w (math.max 1 (or digit-width 2))
        pad (math.max 0 (- w (# s)))]
    (.. (string.rep " " pad) s " ")))

M
