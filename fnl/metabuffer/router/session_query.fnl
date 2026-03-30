(import-macros {: if-some} :io.gitlab.andreyorst.cljlib.core)
(local transform-mod (require :metabuffer.transform))
(local M {})

(fn M.new
  [opts]
  "Build start-query parsing and option-resolution helpers."
  (let [{: history-api : query-mod} (or opts {})]
    (fn expand-history-query
      [start-query]
      (let [latest-history (history-api.history-latest nil)]
        (if (= start-query "!!")
            latest-history
            (= start-query "!$")
            (history-api.history-entry-token latest-history)
            (= start-query "!^!")
            (history-api.history-entry-tail latest-history)
            start-query)))

    (fn start-option-value
      [parsed-query settings parsed-key settings-key]
      (if-some [v (. parsed-query parsed-key)]
        v
        (query-mod.truthy? (. settings settings-key))))

    (fn prompt-query-text
      [parsed-query expanded-query]
      (let [query0 (. parsed-query :query)
            prompt-query0 (if (~= (. parsed-query :include-files) nil)
                              expanded-query
                              query0)]
        {:query query0
         :prompt-query (if (and (= (type prompt-query0) "string")
                                (~= prompt-query0 "")
                                (not (vim.endswith prompt-query0 " "))
                                (not (vim.endswith prompt-query0 "\n")))
                           (.. prompt-query0 " ")
                           prompt-query0)}))

    (fn resolve-start-query-state
      [query settings]
      (let [start-query (or query "")
            expanded-query (expand-history-query start-query)
            parsed-query (query-mod.apply-default-source
                           (query-mod.parse-query-text expanded-query)
                           (query-mod.truthy? settings.default-include-lgrep))
            {: query : prompt-query} (prompt-query-text parsed-query expanded-query)
            start-transforms (transform-mod.enabled-map parsed-query nil settings)]
        {:parsed-query parsed-query
         :query query
         :prompt-query prompt-query
         :start-hidden (start-option-value parsed-query settings :include-hidden :default-include-hidden)
         :start-ignored (start-option-value parsed-query settings :include-ignored :default-include-ignored)
         :start-deps (start-option-value parsed-query settings :include-deps :default-include-deps)
         :start-binary (start-option-value parsed-query settings :include-binary :default-include-binary)
         :start-files (start-option-value parsed-query settings :include-files :default-include-files)
         :start-prefilter (start-option-value parsed-query settings :prefilter :project-lazy-prefilter-enabled)
         :start-lazy (start-option-value parsed-query settings :lazy :project-lazy-enabled)
         :start-expansion (or (. parsed-query :expansion) "none")
         :start-transforms start-transforms}))

    {:resolve-start-query-state resolve-start-query-state}))

M
