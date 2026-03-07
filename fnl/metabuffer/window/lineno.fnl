(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.digit-width-from-max-value
  [max-value]
  (math.max 2 (# (tostring (math.max 1 (or max-value 1))))))

(fn M.digit-width-from-max-len
  [max-len]
  (math.max 2 (or max-len 1)))

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
