(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})

(set M.transform-key "strings")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "strings"
       :token-key :include-strings
       :doc "Extract printable strings from binary files."
       :compat-key :strings}])

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

(fn printable-byte?
  [b]
  (or (= b 9) (>= b 32)))

(fn extract-strings
  [blob]
  (let [out []]
    (var acc [])
    (var start nil)
    (var idx 1)
    (local flush!
      (fn []
        (when (>= (# acc) 4)
          (table.insert out {:text (table.concat acc)
                             :start start
                             :finish (- idx 1)}))
        (set acc [])))
    (each [_ b (ipairs [(string.byte (or blob "") 1 -1)])]
      (if (and b (< b 127) (printable-byte? b))
          (do
            (when (= (# acc) 0)
              (set start idx))
            (table.insert acc (string.char b)))
          (do
            (flush!)
            (set start nil)))
      (set idx (+ idx 1)))
    (flush!)
    out))

(fn strings-lines
  [path size]
  (let [blob (read-bytes path)
        out (and blob (extract-strings blob))]
    (when out
      (let [with-head [(header-line size)]]
        (each [_ item (ipairs out)]
          (table.insert with-head (or (. item :text) "")))
        with-head))))

(fn rebuild-blob
  [blob extracted edited]
  (let [parts []
        cursor0 1]
    (var cursor cursor0)
    (each [idx item (ipairs (or extracted []))]
      (let [start (or (. item :start) cursor)
            finish (or (. item :finish) (- start 1))
            replacement (or (. (or edited []) idx) (. item :text) "")]
        (table.insert parts (string.sub blob cursor (- start 1)))
        (table.insert parts replacement)
        (set cursor (+ finish 1))))
    (table.insert parts (string.sub blob cursor))
    (table.concat parts)))

(fn M.should-apply-file?
  [_path _raw-lines ctx]
  (clj.boolean (and ctx ctx.binary)))

(fn M.apply-file
  [path _raw-lines ctx]
  (strings-lines path (and ctx ctx.size)))

(fn M.reverse-file
  [lines ctx]
  (let [path (and ctx ctx.path)
        blob (and path (read-bytes path))
        extracted (and blob (extract-strings blob))
        body-lines (vim.deepcopy (or lines []))]
    (when (and (> (# body-lines) 0)
               (vim.startswith (or (. body-lines 1) "") "binary "))
      (table.remove body-lines 1))
    (if (or (not blob)
            (not extracted)
            (~= (# body-lines) (# extracted)))
        nil
        (rebuild-blob blob extracted body-lines))))

M
