(local M {})

(fn M.hl-rendered-fg
  [hl]
  "Return effective rendered foreground for HL, accounting for reverse."
  (if (and hl (. hl :reverse))
      (or (. hl :bg) (. hl :fg))
      (. hl :fg)))

(fn M.hl-rendered-bg
  [hl]
  "Return effective rendered background for HL, accounting for reverse."
  (if (and hl (. hl :reverse))
      (or (. hl :fg) (. hl :bg))
      (. hl :bg)))

(fn M.darken-rgb
  [n factor]
  "Darken RGB integer N by FACTOR. Returns adjusted RGB integer or nil."
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)
            f (math.max 0 (math.min factor 1))
            dr (math.max 0 (math.min 255 (math.floor (* r (- 1 f)))))
            dg (math.max 0 (math.min 255 (math.floor (* g (- 1 f)))))
            db (math.max 0 (math.min 255 (math.floor (* b (- 1 f)))))]
        (+ (* dr 0x10000) (* dg 0x100) db))))

(fn M.brighten-rgb
  [n factor]
  "Brighten RGB integer N by FACTOR. Returns adjusted RGB integer or nil."
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)
            f (math.max 0 (math.min factor 1))
            br (math.max 0 (math.min 255 (math.floor (+ r (* (- 255 r) f)))))
            bg (math.max 0 (math.min 255 (math.floor (+ g (* (- 255 g) f)))))
            bb (math.max 0 (math.min 255 (math.floor (+ b (* (- 255 b) f)))))]
        (+ (* br 0x10000) (* bg 0x100) bb))))

(fn M.copy-highlight-with-bg
  [group bg]
  "Return highlight opts copied from GROUP with BG replaced by BG."
  (let [opts {:default true :reverse false :cterm {:reverse false}}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (when (M.hl-rendered-fg hl)
        (set (. opts :fg) (M.hl-rendered-fg hl)))
      (when (. hl :ctermfg)
        (set (. opts :ctermfg) (. hl :ctermfg)))
      (when (. hl :bold)
        (set (. opts :bold) (. hl :bold))))
    (set (. opts :bg) bg)
    opts))

M
