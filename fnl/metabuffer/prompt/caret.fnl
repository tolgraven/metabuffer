(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [prompt locus]
  (local self {:prompt prompt :_locus (or locus 0)})

  (fn self.head
  [] 0)
  (fn self.tail
  [] (# self.prompt.text))

  (fn self.get-locus
  [] self._locus)
  (fn self.set-locus
  [value]
    (if (< value (self.head))
        (set self._locus (self.head))
        (if (> value (self.tail))
            (set self._locus (self.tail))
            (set self._locus value))))

  (fn self.get-backward-text
  []
    (if (= (self.get-locus) 0)
      ""
      (string.sub self.prompt.text 1 (self.get-locus))))

  (fn self.get-selected-text
  []
    (if (>= (self.get-locus) (self.tail))
      ""
      (string.sub self.prompt.text (+ (self.get-locus) 1) (+ (self.get-locus) 1))))

  (fn self.get-forward-text
  []
    (if (>= (self.get-locus) (- (self.tail) 1))
      ""
      (string.sub self.prompt.text (+ (self.get-locus) 2))))

  self)

M
