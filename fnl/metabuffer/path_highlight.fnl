(local M {})
(local util (require :metabuffer.util))

(set M.sep-group "MetaPathSep")
(set M.segment-groups (util.build-group-names "MetaPathSeg" 24))

(fn normalize-segment
  [s]
  (string.lower (vim.trim (tostring (or s "")))))

(fn split-dir-segments
  [dir]
  (let [txt (or dir "")
        raw (vim.split txt "/" {:plain true})
        out []]
    (each [_ seg (ipairs raw)]
      (when (~= seg "")
        (table.insert out seg)))
    out))

(fn map-display-to-original
  [display-segments original-segments]
  (let [disp (or display-segments [])
        orig (or original-segments [])
        mapped []]
    (for [_ 1 (# disp)]
      (table.insert mapped nil))
    (if (= (# disp) (# orig))
        (for [i 1 (# disp)]
          (set (. mapped i) (. orig i)))
        (do
          (when (and (> (# disp) 0)
                     (> (# orig) 0)
                     (not (vim.startswith (or (. disp 1) "") "…")))
            (set (. mapped 1) (. orig 1)))
          (var di (# disp))
          (var oi (# orig))
          (while (and (>= di 1) (>= oi 1))
            (when (= (. mapped di) nil)
              (set (. mapped di) (. orig oi)))
            (set di (- di 1))
            (set oi (- oi 1)))))
    mapped))

(fn M.group-for-segment
  [segment]
  (let [key (normalize-segment segment)
        n (math.max 1 (# M.segment-groups))]
    (if (= key "")
        (. M.segment-groups 1)
        (let [acc0 5381]
          (var acc acc0)
          (for [i 1 (# key)]
            (set acc (% (+ (* acc 33) (string.byte key i)) 2147483647)))
          (. M.segment-groups (+ (% acc n) 1))))))

(fn M.ranges-for-dir
  [dir start-col original-dir]
  (let [txt (or dir "")
        original-segments (split-dir-segments (or original-dir dir))
        display-segments (split-dir-segments dir)
        bucket-segments (map-display-to-original display-segments original-segments)
        out []]
    (var col (or start-col 0))
    (var token "")
    (var token-start col)
    (var seg-idx 0)
    (for [i 1 (# txt)]
      (let [ch (string.sub txt i i)]
        (if (= ch "/")
            (do
              (when (> (# token) 0)
                (set seg-idx (+ seg-idx 1))
                (let [bucket-segment (or (. bucket-segments seg-idx)
                                         (. display-segments seg-idx)
                                         token)]
                (table.insert out {:start token-start
                                   :end col
                                   :hl (M.group-for-segment bucket-segment)}))
                (set token ""))
              (table.insert out {:start col
                                 :end (+ col 1)
                                 :hl M.sep-group})
              (set col (+ col 1))
              (set token-start col))
            (do
              (when (= (# token) 0)
                (set token-start col))
              (set token (.. token ch))
              (set col (+ col 1))))))
    (when (> (# token) 0)
      (set seg-idx (+ seg-idx 1))
      (let [bucket-segment (or (. bucket-segments seg-idx)
                               (. display-segments seg-idx)
                               token)]
      (table.insert out {:start token-start
                         :end col
                         :hl (M.group-for-segment bucket-segment)})))
    out))

M
