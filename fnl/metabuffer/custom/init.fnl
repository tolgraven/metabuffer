(import-macros {: when-let} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))

(local M {})

(local state
  {:config {:transforms {}}
   :providers {:transform []}})

(fn read-bytes
  [path]
  (let [uv (or vim.uv vim.loop)]
    (when (and uv uv.fs_open uv.fs_read uv.fs_close path)
      (let [[ok-open fd] [(pcall uv.fs_open path "r" 438)]]
        (when (and ok-open fd)
          (let [size (or (and uv.fs_fstat
                              (let [[ok-stat stat] [(pcall uv.fs_fstat fd)]]
                                (and ok-stat stat stat.size)))
                         0)
                [ok-read chunk] [(pcall uv.fs_read fd size 0)]]
            (pcall uv.fs_close fd)
            (when ok-read
              (or chunk ""))))))))

(fn sorted-names
  [tbl]
  (let [out []]
    (each [k _ (pairs (or tbl {}))]
      (table.insert out k))
    (table.sort out)
    out))

(fn normalize-command
  [cmd]
  (if (= (type cmd) "string")
      [(or vim.o.shell "sh") (or vim.o.shellcmdflag "-c") cmd]
      (if (= (type cmd) "table")
          cmd
          nil)))

(fn command-output
  [cmd input]
  (let [argv (normalize-command cmd)]
    (when (and argv (> (# argv) 0))
      (let [out (vim.fn.system argv (or input ""))]
        (when (= vim.v.shell_error 0)
          (or out ""))))))

(fn output-lines
  [txt]
  (let [out (vim.split (or txt "") "\n" {:plain true :trimempty false})]
    (while (and (> (# out) 1) (= (. out (# out)) ""))
      (table.remove out))
    out))

(fn detected-filetype
  [path]
  (if (and (= (type path) "string") (~= path ""))
      (let [[ok ft] [(pcall vim.filetype.match {:filename path})]]
        (if (and ok (= (type ft) "string") (~= ft ""))
            ft
            ""))
      ""))

(fn accepts-filetype?
  [spec path]
  (let [wanted (or (. spec :filetypes) [])
        ft (detected-filetype path)]
    (if (or (= (type wanted) "~table") (= (type wanted) "table"))
        (if (= (# wanted) 0)
            true
            (let [matched false]
              (var ok matched)
              (each [_ want (ipairs wanted)]
                (when (and (not ok) (= (or want "") ft))
                  (set ok true)))
              ok))
        true)))

(fn command-spec
  [spec path]
  (let [ft (detected-filetype path)
        by-ft (or (. spec :filetype_commands) {})
        ft-spec (and (~= ft "") (. by-ft ft))]
    (if (= (type ft-spec) "table")
        ft-spec
        spec)))

(fn spec-command
  [spec path k]
  (let [resolved (command-spec spec path)]
    (or (. resolved k) (. spec k))))

(fn applies-to?
  [spec path ctx]
  (let [mode (or (. spec :applies_to) "text")
        binary? (clj.boolean (and ctx ctx.binary))]
    (and (accepts-filetype? spec path)
         (or (= mode "all")
             (and (= mode "binary") binary?)
             (and (= mode "text") (not binary?))))))

(fn line-applicable?
  [spec path line ctx]
  (and (applies-to? spec path ctx)
       (if (= (type (. spec :should_apply_line)) "function")
           (clj.boolean ((. spec :should_apply_line) line ctx))
           (if (= (type (. spec :should_apply)) "function")
               (clj.boolean ((. spec :should_apply) line ctx))
               true))))

(fn file-applicable?
  [spec path raw-lines ctx]
  (and (applies-to? spec path ctx)
       (if (= (type (. spec :should_apply_file)) "function")
           (clj.boolean ((. spec :should_apply_file) path raw-lines ctx))
           (if (= (type (. spec :should_apply)) "function")
               (clj.boolean ((. spec :should_apply) path raw-lines ctx))
               true))))

(fn transform-doc
  [name spec]
  (or (. spec :doc)
      (.. "Run custom transform `" name "`.")))

(fn transform-key
  [name]
  (.. "custom-transform:" name))

(fn token-key
  [name]
  (.. "include-" (transform-key name)))

(fn statusline-label
  [name spec]
  (or (. spec :statusline) name))

(fn line-transform-module
  [name spec]
  {:transform-key (transform-key name)
   :default-enabled (clj.boolean (. spec :enabled))
   :query-directive-specs
   [{:kind "toggle"
     :long (.. "transform:" name)
     :token-key (token-key name)
     :doc (transform-doc name spec)
     :statusline (statusline-label name spec)}]
   :should-apply-line? (fn [line ctx] (line-applicable? spec (and ctx ctx.path) line ctx))
   :apply-line
   (fn [line ctx]
     (when-let [out (command-output (spec-command spec (and ctx ctx.path) :from) (or line ""))]
       (output-lines out)))
   :reverse-line
   (fn [lines ctx]
     (when-let [cmd (spec-command spec (and ctx ctx.path) :to)]
       (when-let [out (command-output cmd (table.concat (or lines []) "\n"))]
         [(or (string.gsub out "\n$" "") out)])))})

(fn file-transform-module
  [name spec]
  {:transform-key (transform-key name)
   :default-enabled (clj.boolean (. spec :enabled))
   :query-directive-specs
   [{:kind "toggle"
     :long (.. "transform:" name)
     :token-key (token-key name)
     :doc (transform-doc name spec)
     :statusline (statusline-label name spec)}]
   :should-apply-file? (fn [path raw-lines ctx]
                          (file-applicable? spec (or (and ctx ctx.path) path) raw-lines ctx))
   :apply-file
   (fn [path raw-lines _ctx]
     (let [ft-path (or (and _ctx _ctx.path) path)
           input (or (read-bytes path) (table.concat (or raw-lines []) "\n"))]
       (when-let [out (command-output (spec-command spec ft-path :from) input)]
         (output-lines out))))
   :reverse-file
   (fn [lines ctx]
     (when-let [cmd (spec-command spec (or (and ctx ctx.path) "") :to)]
       (command-output cmd (table.concat (or lines []) "\n"))))})

(fn transform-module
  [name spec]
  (if (= (or (. spec :scope) "line") "file")
      (file-transform-module name spec)
      (line-transform-module name spec)))

(fn transform-modules
  [cfg]
  (let [out []]
    (each [_ name (ipairs (sorted-names cfg))]
      (let [spec (. cfg name)]
        (when (= (type spec) "table")
          (table.insert out (transform-module name spec)))))
    out))

(fn M.configure!
  [cfg]
  "Configure runtime custom providers. Expected output: current registry state."
  (let [config (vim.deepcopy (or cfg {:transforms {}}))
        transforms (or (. config :transforms) {})]
    (set state.config {:transforms transforms})
    (set state.providers {:transform (transform-modules transforms)})
    state))

(fn M.modules
  [domain]
  "Return configured runtime modules for one domain. Expected output: [{:transform-key \"custom-transform:fmt\"}]."
  (or (. (. state :providers) domain) []))

(fn M.config
  []
  "Return current custom provider config. Expected output: {:transforms {...}}."
  (vim.deepcopy (. state :config)))

M
