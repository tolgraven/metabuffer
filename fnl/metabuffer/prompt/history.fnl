(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [prompt]
  "Public API: M.new."
  (let [self {:prompt prompt :index 0 :cached prompt.text :backward "" :threshold 0}]

    (fn self.current
      []
      (if (= self.index 0)
          self.cached
          (vim.fn.histget "input" (- 0 self.index))))

    (fn self.previous
      []
      (when (= self.index 0)
        (set self.cached self.prompt.text)
        (set self.threshold (vim.fn.histnr "input")))
      (when (< self.index self.threshold)
        (set self.index (+ self.index 1)))
      (self.current))

    (fn self.next
      []
      (when (= self.index 0)
        (set self.cached self.prompt.text)
        (set self.threshold (vim.fn.histnr "input")))
      (when (> self.index 0)
        (set self.index (- self.index 1)))
      (self.current))

    (fn self.previous-match
      []
      (when (= self.index 0)
        (set self.backward (self.prompt.caret.get-backward-text)))
      (var i self.index)
      (var out nil)
      (while (not out)
        (let [c (self.previous)]
          (if (or (= self.index i) (vim.startswith c self.backward))
              (set out c)
              (set i self.index))))
      out)

    (fn self.next-match
      []
      (if (= self.index 0)
          self.cached
          (do
            (var i self.index)
            (var out nil)
            (while (not out)
              (let [c (self.next)]
                (if (or (= self.index i) (vim.startswith c self.backward))
                    (set out c)
                    (set i self.index))))
            out)))

    self))

M
