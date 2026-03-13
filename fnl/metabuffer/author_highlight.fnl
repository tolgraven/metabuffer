(local M {})
(local util (require :metabuffer.util))

(set M.author-groups (util.build-group-names "MetaAuthor" 24))

(set M.author->group {})
(set M.next-group-idx 1)

(fn normalize-author
  [name]
  (string.lower (vim.trim (tostring (or name "")))))

(fn M.group-for-author
  [author]
  (let [key (normalize-author author)
        existing (. M.author->group key)]
    (if existing
        (. M.author-groups existing)
        (let [idx (math.max 1 (math.min (or M.next-group-idx 1) (# M.author-groups)))]
          (set (. M.author->group key) idx)
          (set M.next-group-idx
               (if (< idx (# M.author-groups))
                   (+ idx 1)
                   1))
          (. M.author-groups idx)))))

M
