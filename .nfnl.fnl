{:source-file-patterns ["fnl/**/*.fnl"]
 :orphan-detection {:ignore-patterns ["lua/metabuffer/nfnl/"]}
 :compiler-options {:compilerEnv _G}
 :fnl-path->lua-path
 (fn [fnl-path]
   (let [rel (vim.fn.fnamemodify fnl-path ":.")]
     (if (vim.startswith rel "fnl/plugin/")
       (string.gsub rel "^fnl/plugin/(.*)%.fnl$" "plugin/%1.lua")
       (string.gsub rel "^fnl/(.*)%.fnl$" "lua/%1.lua"))))}
