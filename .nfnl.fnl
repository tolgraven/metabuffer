(let [root (vim.fn.getcwd)
      ;; Helper to append paths
      append-paths (fn [base-paths new-base-dir patterns]
                     (let [acc base-paths]
                       (each [_ pat (ipairs patterns)]
                         (table.insert acc (.. new-base-dir "/" pat)))
                       acc))
      append-current-path! (fn [existing current-path]
                             (let [seen {}]
                               (each [_ entry (ipairs existing)]
                                 (when (and entry (not= entry ""))
                                   (tset seen entry true)))
                               (each [_ part (ipairs (vim.split (or current-path "") ";" {:plain true :trimempty true}))]
                                 (when (and part (not= part "") (not (. seen part)))
                                   (table.insert existing part)
                                   (tset seen part true)))
                               existing))
      
      ;; Start with basic paths
      fnl-paths [(.. root "/fnl/?.fnl")
                 (.. root "/fnl/?/init.fnl")]
      macro-paths [(.. root "/fnl/?.fnl")
                   (.. root "/fnl/?/init.fnl")]
      lua-version (or (_VERSION:match "([0-9]+%.[0-9]+)") "5.1")
      lua-paths [(.. root "/lua/?.lua")
                 (.. root "/lua/?/init.lua")
                 (.. root "/plugin/?.lua")]
      lua-cpaths []
      
      ;; Add vendored deps in deps/
      fnl-patterns ["src/?.fnl" "src/?/init.fnl" "?.fnl" "?/init.fnl"]
      macro-patterns ["src/?.fnlm" "src/?/init.fnlm" "?.fnlm" "?/init.fnlm"
                      "src/?.fnl" "src/?/init.fnl" "?.fnl" "?/init.fnl"]
      
      ;; Check deps/ directory
      deps (vim.fn.glob (.. root "/deps/*") true true)]
  (each [_ d (ipairs deps)]
    (append-paths fnl-paths d fnl-patterns)
    (append-paths macro-paths d macro-patterns))
    
  ;; Check .deps/git directory (managed by potential deps tool)
  (let [git-deps (vim.fn.glob (.. root "/.deps/git/*/*/*") true true)]
    (each [_ d (ipairs git-deps)]
      (append-paths fnl-paths d fnl-patterns)
      (append-paths macro-paths d macro-patterns)))

  ;; Add Lua/Lua C module paths from rock installs under .deps/rocks.
  (let [rock-lua-dirs (vim.fn.glob (.. root "/.deps/rocks/*/*/share/lua/" lua-version) true true)
        rock-lib-dirs (vim.fn.glob (.. root "/.deps/rocks/*/*/lib/lua/" lua-version) true true)]
    (each [_ d (ipairs rock-lua-dirs)]
      (append-paths lua-paths d ["?.lua" "?/init.lua"]))
    (each [_ d (ipairs rock-lib-dirs)]
      (append-paths lua-cpaths d ["?.so" "?/?.so"])))

  (append-current-path! lua-paths package.path)
  (append-current-path! lua-cpaths package.cpath)
  (set package.path (table.concat lua-paths ";"))
  (set package.cpath (table.concat lua-cpaths ";"))

  {:source-file-patterns ["fnl/**/*.fnl" ".deps/git/*/*/*/src/**/*.fnl"]
   :orphan-detection {:ignore-patterns ["lua/metabuffer/nfnl/"]}
   :compiler-options {:compilerEnv _G}
   :fennel-path (table.concat fnl-paths ";")
   :fennel-macro-path (table.concat macro-paths ";")
   :fnl-path->lua-path
   (fn [fnl-path]
     (let [rel (vim.fn.fnamemodify fnl-path ":.")]
       (if
         (vim.startswith rel "fnl/plugin/")
         (string.gsub rel "^fnl/plugin/(.*)%.fnl$" "plugin/%1.lua")
         (vim.startswith rel "fnl/")
         (string.gsub rel "^fnl/(.*)%.fnl$" "lua/%1.lua")
         ;; Handle .deps/git paths
         (let [m (rel:match "%.deps/git/[^/]+/[^/]+/[^/]+/src/(.*)%.fnl$")]
           (if m
               (if (m:match "/init$")
                   (.. "lua/" (m:sub 1 -6) "/init.lua")
                   (.. "lua/" m ".lua"))
               (string.gsub rel "%.fnl$" ".lua"))))))})
