(local M {})
(local util (require :metabuffer.util))

(set M.sep-group "MetaPathSep")
(set M.segment-groups (util.build-group-names "MetaPathSeg" 24))

(set M.segment->group {})
(set M.next-group-idx 1)

(fn normalize-segment
  [s]
  (let [txt (string.lower (tostring (or s "")))]
    (if (= txt "")
        ""
        ;; Keep compacted and full path segments color-stable (`f` == `fnl`).
        (string.sub txt 1 1))))

(fn M.group-for-segment
  [segment]
  (let [key (normalize-segment segment)
        existing (. M.segment->group key)]
    (if existing
        (. M.segment-groups existing)
        (let [idx (math.max 1 (math.min (or M.next-group-idx 1) (# M.segment-groups)))]
          (set (. M.segment->group key) idx)
          (set M.next-group-idx
               (if (< idx (# M.segment-groups))
                   (+ idx 1)
                   1))
          (. M.segment-groups idx)))))

(fn M.ranges-for-dir
  [dir start-col]
  (let [txt (or dir "")
        out []]
    (var col (or start-col 0))
    (var token "")
    (var token-start col)
    (for [i 1 (# txt)]
      (let [ch (string.sub txt i i)]
        (if (= ch "/")
            (do
              (when (> (# token) 0)
                (table.insert out {:start token-start
                                   :end col
                                   :hl (M.group-for-segment token)})
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
      (table.insert out {:start token-start
                         :end col
                         :hl (M.group-for-segment token)}))
    out))

M
