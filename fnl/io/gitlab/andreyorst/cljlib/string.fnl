(import-macros {: defn}
  :io.gitlab.andreyorst.cljlib.core)

(defn join
  [separator parts]
  "Public API: clojure.string/join-style helper. Returns joined string."
  (table.concat (or parts []) (or separator "")))

(defn lower-case
  [text]
  "Public API: clojure.string/lower-case-style helper. Returns lower string."
  (string.lower (or text "")))

(defn replace
  [text match replacement]
  "Public API: clojure.string/replace-style helper. Returns replaced string."
  (let [[result] [(string.gsub (or text "") match (or replacement ""))]]
    result))

(defn starts-with?
  [text prefix]
  "Public API: clojure.string/starts-with?-style helper. Returns boolean."
  (vim.startswith (or text "") (or prefix "")))

(defn substring
  "Public API: clojure.string/substring-style helper. Returns substring."
  ([text start]
   (string.sub (or text "") start))
  ([text start finish]
   (string.sub (or text "") start finish)))

(defn match
  [text pattern]
  "Public API: clojure.string/match-style helper. Returns first match."
  (string.match (or text "") (or pattern "")))

{:join join
 :lower-case lower-case
 :replace replace
 :starts-with? starts-with?
 :substring substring
 :match match}
