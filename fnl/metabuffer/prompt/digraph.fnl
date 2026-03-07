(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local util (require :metabuffer.prompt.util))

(local M {})
(var _instance nil)

(fn parse_digraph_output
  [output]
  (let [registry {}]
    (each [_ line (ipairs (vim.split (or output "") "\n" {:trimempty true}))]
      (let [k (string.match line "(%S%S)%s+%S+%s+%d+")
            v (string.match line "%S%S%s+(%S+)%s+%d+")]
        (when (and k v)
          (set (. registry k) v))))
    registry))

(fn M.new
  []
  "Public API: M.new."
  (if _instance
      _instance
      (do
        (set _instance {:registry nil})

        (fn _instance.find
  [_ ch1 ch2]
          (when-not _instance.registry
            (set _instance.registry (parse_digraph_output (vim.fn.execute "digraphs"))))
          (or (. _instance.registry (.. ch1 ch2))
              (. _instance.registry (.. ch2 ch1))
              ch2))

        (fn _instance.retrieve
  [_]
          (let [code1 (util.getchar)]
            (if (and (= (type code1) "string") (vim.startswith code1 "<"))
                code1
                (let [code2 (util.getchar)]
                  (if (and (= (type code2) "string") (vim.startswith code2 "<"))
                      code2
                      (let [ch1 (if (= (type code1) "number") (util.int2char code1) (tostring code1))
                            ch2 (if (= (type code2) "number") (util.int2char code2) (tostring code2))]
                        (_instance.find _instance ch1 ch2)))))))

        _instance)))

M
