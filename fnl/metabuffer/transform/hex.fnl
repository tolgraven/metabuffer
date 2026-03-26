(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})

(set M.transform-key "hex")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "hex"
       :token-key :include-hex
       :doc "Render binary files through hex view."
       :compat-key :hex}])

(fn header-line
  [size]
  (let [kb (math.max 1 (math.floor (/ (math.max 0 (or size 0)) 1024)))]
    (.. "binary " (tostring kb) " KB")))

(fn read-bytes
  [path]
  (let [uv (or vim.uv vim.loop)]
    (when (and uv uv.fs_open uv.fs_read uv.fs_close path)
      (let [[ok-open fd] [(pcall uv.fs_open path "r" 438)]]
        (when (and ok-open fd)
          (let [size (or (and uv.fs_fstat
                              (let [[ok-stat stat] [(pcall uv.fs_fstat fd)]]
                                (and ok-stat stat stat.size)))
                         0)
                [ok-read chunk] [(pcall uv.fs_read fd size 0)]]
            (pcall uv.fs_close fd)
            (when ok-read
              (or chunk ""))))))))

(fn hex-byte
  [b]
  (string.format "%02X" b))

(fn ascii-byte
  [b]
  (if (and (>= b 32) (<= b 126))
      (string.char b)
      "."))

(fn hex-view-lines
  [blob size]
  (let [lines [(header-line size)]
        n (# (or blob ""))]
    (for [offset 0 (- n 1) 16]
      (let [hex-left []
            hex-right []
            ascii []
            line-end (math.min n (+ offset 16))]
        (for [i offset (- line-end 1)]
          (let [b (string.byte blob (+ i 1))]
            (table.insert (if (< (- i offset) 8) hex-left hex-right) (hex-byte b))
            (table.insert ascii (ascii-byte b))))
        (let [left-str (table.concat hex-left " ")
              right-str (table.concat hex-right " ")
              left-pad (string.rep " " (math.max 0 (- 23 (# left-str))))
              right-pad (string.rep " " (math.max 0 (- 23 (# right-str))))
              ascii-str (table.concat ascii "")]
          (table.insert
           lines
           (string.format "%08X: %s%s  %s%s  %s"
                          offset
                          left-str
                          left-pad
                          right-str
                          right-pad
                          ascii-str)))))
    lines))

(fn M.should-apply-file?
  [_path _raw-lines ctx]
  (clj.boolean (and ctx ctx.binary)))

(fn M.apply-file
  [path _raw-lines ctx]
  (let [blob (read-bytes path)]
    (when blob
      (hex-view-lines blob (and ctx ctx.size)))))

(fn parse-hex-line
  [line]
  (let [trimmed (vim.trim (or line ""))]
    (when (and (~= trimmed "") (not (vim.startswith trimmed "binary ")))
      (let [payload (string.match trimmed "^[0-9A-Fa-f]+:%s*(.+)$")]
        (when (and payload (~= payload ""))
          (let [out []]
            (let [hex-zone (if (>= (# payload) 48)
                               (string.sub payload 1 48)
                               payload)]
              (each [_ tok (ipairs (vim.split hex-zone "%s+" {:plain false :trimempty true}))]
              (when (string.match tok "^[0-9A-Fa-f][0-9A-Fa-f]$")
                  (table.insert out (tonumber tok 16)))))
            out))))))

(fn M.reverse-file
  [lines _ctx]
  (let [bytes []]
    (each [_ line (ipairs (or lines []))]
      (each [_ b (ipairs (or (parse-hex-line line) []))]
        (table.insert bytes b)))
    (let [chars []]
      (each [_ b (ipairs bytes)]
        (table.insert chars (string.char b)))
      (table.concat chars))))

M
