(local M {})

(fn M.new [candidates index opts]
  (local self {:candidates candidates
               :index (or index 1)
               :on-leave (and opts opts.on-leave)
               :on-active (and opts opts.on-active)})

  (fn self.current []
    (. self.candidates self.index))

  (fn self._call [f]
    (when f
      (if (= (type f) "string")
          (let [obj (self.current)
                m (. obj f)]
            (when m (m obj)))
          (f self))))

  (fn self.set-index [value]
    (when (~= value self.index)
      (self._call self.on-leave)
      (set self.index (+ (% (- value 1) (# self.candidates)) 1))
      (self._call self.on-active)))

  (fn self.next [offset]
    (self.set-index (+ self.index (or offset 1)))
    (self.current))

  (fn self.previous [offset]
    (self.set-index (- self.index (or offset 1)))
    (self.current))

  self)

M
