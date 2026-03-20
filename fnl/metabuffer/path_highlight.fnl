(local M {})
(local util (require :metabuffer.util))

(set M.sep-group "MetaPathSep")
(set M.segment-groups (util.build-group-names "MetaPathSeg" 24))

(fn normalize-segment
  [s]
  (string.lower (vim.trim (tostring (or s "")))))

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
