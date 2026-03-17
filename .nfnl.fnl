(let [root (vim.fn.getcwd)
      fnl-path (.. root "/fnl/?.fnl;"
                   root "/fnl/?/init.fnl;"
                   root "/deps/fennel-cljlib/src/?.fnl;"
                   root "/deps/fennel-cljlib/src/?/init.fnl")
      macro-path (.. root "/fnl/?.fnl;"
                     root "/fnl/?/init.fnl;"
                     root "/deps/fennel-cljlib/src/?.fnlm;"
                     root "/deps/fennel-cljlib/src/?/init.fnlm")]
  {:source-file-patterns ["fnl/**/*.fnl"]
   :orphan-detection {:ignore-patterns ["lua/metabuffer/nfnl/"]}
   :compiler-options {:compilerEnv _G}
   :fennel-path fnl-path
   :fennel-macro-path macro-path
   :fnl-path->lua-path
   (fn [fnl-path]
     (let [rel (vim.fn.fnamemodify fnl-path ":.")]
       (if (vim.startswith rel "fnl/plugin/")
         (string.gsub rel "^fnl/plugin/(.*)%.fnl$" "plugin/%1.lua")
         (string.gsub rel "^fnl/(.*)%.fnl$" "lua/%1.lua"))))})
