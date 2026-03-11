(local M {})

(set M.sep-group "MetaPathSep")

(set M.segment-groups
  ["MetaPathSeg1"
   "MetaPathSeg2"
   "MetaPathSeg3"
   "MetaPathSeg4"
   "MetaPathSeg5"
   "MetaPathSeg6"
   "MetaPathSeg7"
   "MetaPathSeg8"
   "MetaPathSeg9"
   "MetaPathSeg10"
   "MetaPathSeg11"
   "MetaPathSeg12"
   "MetaPathSeg13"
   "MetaPathSeg14"
   "MetaPathSeg15"
   "MetaPathSeg16"
   "MetaPathSeg17"
   "MetaPathSeg18"
   "MetaPathSeg19"
   "MetaPathSeg20"
   "MetaPathSeg21"
   "MetaPathSeg22"
   "MetaPathSeg23"
   "MetaPathSeg24"])

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
