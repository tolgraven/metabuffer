(if (= vim.g.loaded_metabuffer 1)
    nil
    (do
      (set vim.g.loaded_metabuffer 1)

      (set (. vim.g "meta#custom_mappings") (or (. vim.g "meta#custom_mappings") {}))
      (set (. vim.g "meta#highlight_groups") (or (. vim.g "meta#highlight_groups") {:All "Title" :Fuzzy "Number" :Regex "Special"}))
      (set (. vim.g "meta#syntax_on_init") (or (. vim.g "meta#syntax_on_init") "buffer"))
      (set (. vim.g "meta#prefix") (or (. vim.g "meta#prefix") "#"))

      (local hi vim.api.nvim_set_hl)
      (hi 0 "MetaStatuslineModeInsert" {:link "Tag" :default true})
      (hi 0 "MetaStatuslineModeReplace" {:link "Todo" :default true})
      (hi 0 "MetaStatuslineQuery" {:link "Normal" :default true})
      (hi 0 "MetaStatuslineFile" {:link "Comment" :default true})
      (hi 0 "MetaStatuslineMiddle" {:link "Normal" :default true})
      (hi 0 "MetaStatuslineMatcherAll" {:link "Statement" :default true})
      (hi 0 "MetaStatuslineMatcherFuzzy" {:link "Number" :default true})
      (hi 0 "MetaStatuslineMatcherRegex" {:link "Special" :default true})
      (hi 0 "MetaStatuslineCaseSmart" {:link "String" :default true})
      (hi 0 "MetaStatuslineCaseIgnore" {:link "Special" :default true})
      (hi 0 "MetaStatuslineCaseNormal" {:link "Normal" :default true})
      (hi 0 "MetaStatuslineSyntaxBuffer" {:link "Normal" :default true})
      (hi 0 "MetaStatuslineSyntaxMeta" {:link "Number" :default true})
      (hi 0 "MetaStatuslineIndicator" {:link "Tag" :default true})
      (hi 0 "MetaStatuslineKey" {:link "Comment" :default true})
      (hi 0 "MetaSearchHitAll" {:link "MetaStatuslineMatcherAll" :default true})
      (hi 0 "MetaSearchHitBuffer" {:link "MetaStatuslineMatcherAll" :default true})
      (hi 0 "MetaSearchHitFuzzy" {:link "MetaStatuslineMatcherFuzzy" :default true})
      (hi 0 "MetaSearchHitFuzzyBetween" {:link "IncSearch" :default true})
      (hi 0 "MetaSearchHitRegex" {:link "MetaStatuslineMatcherRegex" :default true})

      (let [m (require :metabuffer)]
        (m.setup))))
