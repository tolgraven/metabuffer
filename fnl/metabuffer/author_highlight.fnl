(local M {})
(local util (require :metabuffer.util))

(set M.author-groups (util.build-group-names "MetaAuthor" 24))

(fn normalize-author
  [name]
  (string.lower (vim.trim (tostring (or name "")))))

(fn bucket-for-author
  [author]
  (let [key (normalize-author author)
        n (math.max 1 (# M.author-groups))]
    (if (= key "")
        1
        (let [acc0 5381]
          (var acc acc0)
          (for [i 1 (# key)]
            (set acc (% (+ (* acc 33) (string.byte key i)) 2147483647)))
          (+ (% acc n) 1)))))

(fn M.group-for-author
  [author]
  (. M.author-groups (bucket-for-author author)))

M
