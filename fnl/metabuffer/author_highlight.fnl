(local M {})

(set M.author-groups
  ["MetaAuthor1"
   "MetaAuthor2"
   "MetaAuthor3"
   "MetaAuthor4"
   "MetaAuthor5"
   "MetaAuthor6"
   "MetaAuthor7"
   "MetaAuthor8"
   "MetaAuthor9"
   "MetaAuthor10"
   "MetaAuthor11"
   "MetaAuthor12"
   "MetaAuthor13"
   "MetaAuthor14"
   "MetaAuthor15"
   "MetaAuthor16"
   "MetaAuthor17"
   "MetaAuthor18"
   "MetaAuthor19"
   "MetaAuthor20"
   "MetaAuthor21"
   "MetaAuthor22"
   "MetaAuthor23"
   "MetaAuthor24"])

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
