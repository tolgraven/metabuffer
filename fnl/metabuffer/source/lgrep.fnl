(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local text (require :metabuffer.source.text))
(local util (require :metabuffer.util))
(local M {})
(set M.provider-key "lgrep")
(set M.query-directive-specs
     [{:kind "flag"
       :long "lgrep"
       :token-key :source-mode
       :arg "{query}"
       :doc "Switch the source set to lgrep semantic search hits."
       :value "search"
       :await {:kind "query-source" :source-key "lgrep" :mode "search"}}
      {:kind "flag"
       :long "lgrep:u"
       :token-key :source-mode
       :arg "{symbol}"
       :doc "Switch the source set to lgrep usages for a symbol."
       :value "usages"
       :await {:kind "query-source" :source-key "lgrep" :mode "usages"}}
      {:kind "flag"
       :long "lgrep:d"
       :token-key :source-mode
       :arg "{symbol}"
       :doc "Switch the source set to lgrep definitions for a symbol."
       :value "definition"
       :await {:kind "query-source" :source-key "lgrep" :mode "definition"}}])

(fn active-specs
  [parsed]
  "Return normalized active lgrep query specs. Expected output: [{:kind \"search\" :query \"setup\"}]."
  (let [source-lines (or (. parsed :source-lines) (. parsed :lgrep-lines) [])
        out []]
    (each [_ spec (ipairs source-lines)]
      (when (and spec
                 (= (type spec) "table")
                 (= (or (. spec :key) "lgrep") "lgrep")
                 (~= (vim.trim (or (. spec :query) "")) ""))
        (table.insert out {:kind (or (. spec :kind) "search")
                           :query (vim.trim (or (. spec :query) ""))})))
    out))

(fn M.active?
  [parsed]
  "Return true when parsed query enables lgrep. Expected output: true."
  (> (# (active-specs parsed)) 0))

(fn M.signature
  [parsed]
  "Return stable signature for active lgrep query specs. Expected output: \"search:setup|definition:main\"."
  (let [parts []]
    (each [_ spec (ipairs (active-specs parsed))]
      (table.insert parts (.. (or (. spec :kind) "search")
                              ":"
                              (or (. spec :query) ""))))
    (table.concat parts "|")))

(fn M.debounce-ms
  [settings _parsed]
  "Return debounce floor for lgrep-backed prompt updates. Expected output: 260."
  (math.max 0 (or settings.lgrep-debounce-ms 260)))

(fn M.hit-prefix
  [ref]
  (text.hit-prefix ref))

(fn M.info-path
  [ref full-path?]
  (text.info-path ref full-path?))

(fn M.info-suffix
  [session ref mode read-file-lines-cached read-file-view-cached]
  (text.info-suffix session ref mode read-file-lines-cached read-file-view-cached))

(fn M.info-meta
  [session ref]
  (text.info-meta session ref))

(fn source-sign
  [ref]
  (let [lgrep-kind (or (and ref (. ref :lgrep-kind)) "")]
    (if (= lgrep-kind "usages")
        (util.icon-sign {:category "lsp" :name "reference" :fallback "" :hl "MiniIconsCyan"})
        (= lgrep-kind "definition")
        (util.icon-sign {:category "lsp" :name "function" :fallback "" :hl "MiniIconsPurple"})
        (util.icon-sign {:category "filetype" :name "telescopeprompt" :fallback "󰍉" :hl "MiniIconsGreen"}))))

(fn M.info-view
  [session ref ctx]
  (let [view (text.info-view session ref ctx)]
    (set (. view :sign) (source-sign ref))
    view))

(fn M.preview-filetype
  [ref]
  (text.preview-filetype ref))

(fn M.preview-lines
  [session ref height read-file-lines-cached read-file-view-cached]
  (text.preview-lines session ref height read-file-lines-cached read-file-view-cached))

(fn absolute-path
  [root path canonical-path]
  (let [p (or path "")]
    (if (= p "")
        nil
        (if (vim.startswith p "/")
            (canonical-path p)
            (canonical-path (.. root "/" p))))))

(fn run-command
  [settings spec]
  (let [bin (or settings.lgrep-bin "lgrep")
        limit (tostring (or settings.lgrep-limit 80))
        cmd (if (= spec.kind "usages")
                [bin "search" "--usages" spec.query "-j" "-l" limit]
                (= spec.kind "definition")
                [bin "search" "--definition" spec.query "-j" "-l" limit]
                [bin "search" spec.query "-j" "-l" limit])
        out (vim.fn.system cmd)]
    (if (not (= vim.v.shell_error 0))
        {:count 0 :results []}
        (let [[ok decoded] [(pcall vim.json.decode out)]]
          (if (and ok (= (type decoded) "table"))
              decoded
              {:count 0 :results []})))))

(fn resolve-runner
  [settings]
  (or (and (= (type settings.lgrep-runner) "function") settings.lgrep-runner)
      (and (= (type _G.__meta_test_lgrep_runner) "function") _G.__meta_test_lgrep_runner)
      run-command))

(fn add-result!
  [groups root canonical-path spec result]
  (let [path (absolute-path root (or (. result :file) "") canonical-path)
        line0 (or (tonumber (. result :line)) 1)
        score (or (tonumber (. result :score)) 0)
        chunk (or (. result :chunk) "")
        bucket-key (or path "")]
    (when path
      (let [bucket (or (. groups bucket-key) {:path path :best-score score :items []})]
        (set (. bucket :best-score) (math.max (or (. bucket :best-score) score) score))
        (table.insert (. bucket :items) {:path path
                                         :line line0
                                         :score score
                                         :chunk chunk
                                         :kind spec.kind
                                         :query spec.query})
        (set (. groups bucket-key) bucket)))))

(fn sort-groups
  [groups]
  (let [out []]
    (each [_ bucket (pairs groups)]
      (table.insert out bucket))
    (table.sort out
      (fn [a b]
        (if (= (or (. a :best-score) 0) (or (. b :best-score) 0))
            (< (or (. a :path) "") (or (. b :path) ""))
            (> (or (. a :best-score) 0) (or (. b :best-score) 0)))))
    out))

(fn sort-items!
  [items]
  (table.sort items
    (fn [a b]
      (if (= (or (. a :line) 0) (or (. b :line) 0))
          (> (or (. a :score) 0) (or (. b :score) 0))
          (< (or (. a :line) 0) (or (. b :line) 0))))))

(fn append-item!
  [content refs item]
  (let [chunk-lines (vim.split (or (. item :chunk) "") "\n" {:plain true :trimempty false})
        lines (if (> (# chunk-lines) 0) chunk-lines [""])
        line0 (math.max 1 (or (. item :line) 1))]
    (each [idx line (ipairs lines)]
      (let [lnum (+ line0 idx -1)
            text (or line "")]
        (table.insert content text)
        (table.insert refs {:path (. item :path)
                            :lnum lnum
                            :open-lnum lnum
                            :preview-lnum lnum
                            :line text
                            :kind "lgrep-hit"
                            :lgrep-kind (. item :kind)
                            :lgrep-query (. item :query)
                            :lgrep-score (. item :score)})))))

(fn M.collect-source-set
  [settings parsed canonical-path]
  "Build metabuffer content/refs from lgrep JSON results. Expected output: {:content [...] :refs [...]}."
  (let [specs (active-specs parsed)]
    (if (= (# specs) 0)
        nil
        (let [runner (resolve-runner settings)
              root (vim.fn.getcwd)
              groups {}]
          (each [_ spec (ipairs specs)]
            (let [decoded (or (runner settings spec) {:count 0 :results []})]
              (each [_ result (ipairs (or (. decoded :results) []))]
                (add-result! groups root canonical-path spec result))))
          (let [content []
                refs []]
            (each [_ bucket (ipairs (sort-groups groups))]
              (sort-items! (. bucket :items))
              (each [_ item (ipairs (or (. bucket :items) []))]
                (append-item! content refs item)))
            {:content content :refs refs})))))

M
