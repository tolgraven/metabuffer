(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local custom-mod (require :metabuffer.custom))
(local hex (require :metabuffer.transform.hex))
(local strings (require :metabuffer.transform.strings))
(local b64 (require :metabuffer.transform.b64))
(local bplist (require :metabuffer.transform.bplist))
(local json (require :metabuffer.transform.json))
(local xml (require :metabuffer.transform.xml))
(local css (require :metabuffer.transform.css))

(local M {})

(local builtin-modules [bplist hex strings b64 json xml css])

(fn modules
  []
  (let [out []]
    (each [_ mod (ipairs builtin-modules)]
      (table.insert out mod))
    (each [_ mod (ipairs (custom-mod.modules :transform))]
      (table.insert out mod))
    out))

(fn state-key
  [name]
  (.. "include-" (or name "")))

(fn effective-state-key
  [name]
  (.. "effective-" (state-key name)))

(fn setting-key
  [name]
  (.. "default-include-" (or name "")))

(fn module-key
  [mod]
  (or (. mod :transform-key) ""))

(fn all-specs
  []
  (let [out []]
    (each [_ mod (ipairs (modules))]
      (let [specs (if (= (type (. mod :query-directive-specs)) "function")
                      ((. mod :query-directive-specs))
                      (or (. mod :query-directive-specs) []))]
        (each [_ spec (ipairs specs)]
          (table.insert out spec))))
    out))

(set M.query-directive-specs all-specs)

(fn M.modules
  []
  (modules))

(fn M.module-keys
  []
  (let [out []]
    (each [_ mod (ipairs (modules))]
      (table.insert out (module-key mod)))
    out))

(fn session-flag
  [session name]
  (or (and session session.effective-transforms (. session.effective-transforms name))
      (and session session.transform-flags (. session.transform-flags name))
      (and session (. session (effective-state-key name)))
      (and session (. session (state-key name)))))

(fn M.enabled-map
  [parsed session settings]
  (let [out {}]
    (each [_ mod (ipairs (modules))]
      (let [name (module-key mod)
            key (state-key name)
            parsed-v (and parsed (. parsed key))
            session-v (session-flag session name)
            setting-v (and settings (. settings (setting-key name)))
            module-default (. mod :default-enabled)
            value (if (~= parsed-v nil)
                      parsed-v
                      (if (~= session-v nil)
                          session-v
                          (if (~= setting-v nil)
                              setting-v
                              module-default)))]
        (set (. out name) (clj.boolean value))))
    out))

(fn compat-key
  [mod]
  (let [specs (if (= (type (. mod :query-directive-specs)) "function")
                  ((. mod :query-directive-specs))
                  (or (. mod :query-directive-specs) []))
        spec (. specs 1)]
    (and spec (. spec :compat-key))))

(fn M.apply-flags!
  [target flags]
  "Write generic and compatibility transform booleans onto a session-like table. Expected output: target."
  (when target
    (set target.transform-flags (vim.deepcopy (or flags {})))
    (set target.effective-transforms (vim.deepcopy (or flags {})))
    (each [_ mod (ipairs (modules))]
      (let [name (module-key mod)
            enabled (clj.boolean (. (or flags {}) name))
            key (state-key name)
            compat (compat-key mod)]
        (set (. target key) enabled)
        (set (. target (effective-state-key name)) enabled)
        (when compat
          (set (. target compat) enabled)))))
  target)

(fn M.compat-view
  [flags]
  "Return compatibility fields for enabled transform flags. Expected output: {:include-hex true :hex true}."
  (let [out {}]
    (each [_ mod (ipairs (modules))]
      (let [name (module-key mod)
            enabled (clj.boolean (. (or flags {}) name))
            key (state-key name)
            compat (compat-key mod)]
        (set (. out key) enabled)
        (when compat
          (set (. out compat) enabled))))
    out))

(fn M.signature
  [flags]
  (let [parts []]
    (each [_ mod (ipairs (modules))]
      (let [name (module-key mod)]
        (when (. flags name)
          (table.insert parts name))))
    (table.concat parts "|")))

(fn identity-view
  [lines]
  (let [out []
        line-map []
        row-meta []]
    (each [lnum line (ipairs (or lines []))]
      (table.insert out (or line ""))
      (table.insert line-map lnum)
      (table.insert row-meta {:source-lnum lnum
                              :source-text (or line "")
                              :source-group-id lnum
                              :source-group-kind "line"
                              :transform-chain []}))
    {:lines out :line-map line-map :row-meta row-meta}))

(fn file-view
  [lines transform-name]
  (let [out []
        line-map []
        row-meta []]
    (each [_ line (ipairs (or lines []))]
      (table.insert out (or line ""))
      (table.insert line-map 1)
      (table.insert row-meta {:source-lnum 1
                              :source-group-id 1
                              :source-group-kind "file"
                              :transform-chain [transform-name]}))
    {:lines out :line-map line-map :row-meta row-meta}))

(fn limited-lines
  [lines]
  (let [cap 400]
    (if (<= (# (or lines [])) cap)
        (or lines [])
        (let [out []]
          (for [i 1 cap]
            (table.insert out (. lines i)))
          (table.insert out "... [transform truncated]")
          out))))

(fn wrap-one-line
  [line width linebreak?]
  (let [txt (or line "")
        maxw (math.max 1 (or width 1))
        out []]
    (if (<= (vim.fn.strdisplaywidth txt) maxw)
        [txt]
        (do
          (var rest txt)
          (while (> (# rest) 0)
            (if (<= (vim.fn.strdisplaywidth rest) maxw)
                (do
                  (table.insert out rest)
                  (set rest ""))
                (let [chars (vim.fn.strchars rest)
                      cut0 1]
                  (var cut cut0)
                  (for [i 1 chars]
                    (when (<= (vim.fn.strdisplaywidth (vim.fn.strcharpart rest 0 i)) maxw)
                      (set cut i)))
                  (when (and linebreak? (> cut 1))
                    (let [chunk0 (vim.fn.strcharpart rest 0 cut)
                          ws (string.match chunk0 ".*()%s+%S*$")]
                      (when (and ws (> ws 1))
                        (set cut (- ws 1)))))
                  (let [chunk (vim.trim (vim.fn.strcharpart rest 0 cut))
                        next-rest (vim.trim (vim.fn.strcharpart rest cut))]
                    (table.insert out (if (= chunk "") (vim.fn.strcharpart rest 0 cut) chunk))
                    (set rest next-rest)))))
          (if (> (# out) 0) out [""])))))

(fn wrap-view
  [view width linebreak?]
  (let [out []
        line-map []
        row-meta []]
    (each [idx line (ipairs (or (. view :lines) []))]
      (let [mapped (or (. (. view :line-map) idx) idx)
            meta (or (. (. view :row-meta) idx) {:source-lnum mapped
                                                 :source-text (or line "")
                                                 :source-group-id mapped
                                                 :source-group-kind "line"
                                                 :transform-chain []})
            chunks (wrap-one-line line width linebreak?)]
        (each [_ chunk (ipairs chunks)]
          (table.insert out chunk)
          (table.insert line-map mapped)
          (table.insert row-meta (vim.deepcopy meta)))))
    {:lines out :line-map line-map :row-meta row-meta}))

(fn apply-line-transform
  [view mod ctx]
  (let [out []
        line-map []
        row-meta []]
    (each [idx line (ipairs (or (. view :lines) []))]
      (let [orig-lnum (or (. (. view :line-map) idx) idx)
            meta0 (or (. (. view :row-meta) idx) {:source-lnum orig-lnum
                                                  :source-text (or line "")
                                                  :source-group-id orig-lnum
                                                  :source-group-kind "line"
                                                  :transform-chain []})
            local-ctx (vim.tbl_extend "force" ctx {:lnum orig-lnum})]
        (if ((. mod :should-apply-line?) line local-ctx)
            (let [produced (limited-lines ((. mod :apply-line) line local-ctx))]
              (if (> (# produced) 0)
                  (each [_ item (ipairs produced)]
                    (table.insert out (or item ""))
                    (table.insert line-map orig-lnum)
                    (table.insert row-meta
                                  (vim.tbl_extend "force"
                                                  (vim.deepcopy meta0)
                                                  {:transform-chain
                                                   (vim.list_extend
                                                     (vim.deepcopy (or (. meta0 :transform-chain) []))
                                                     [(module-key mod)])})))
                  (do
                    (table.insert out (or line ""))
                    (table.insert line-map orig-lnum)
                    (table.insert row-meta (vim.deepcopy meta0)))))
            (do
              (table.insert out (or line ""))
              (table.insert line-map orig-lnum)
              (table.insert row-meta (vim.deepcopy meta0))))))
    {:lines out :line-map line-map :row-meta row-meta}))

(fn module-by-name
  [name]
  (let [found nil]
    (var out found)
    (each [_ mod (ipairs (modules))]
      (when (and (not out) (= (module-key mod) name))
        (set out mod)))
    out))

(fn reverse-line-group
  [meta lines ctx]
  (let [chain (vim.deepcopy (or (. meta :transform-chain) []))
        current (vim.deepcopy (or lines []))]
    (var cur current)
    (for [i (# chain) 1 -1]
      (let [mod (module-by-name (. chain i))
            f (and mod (. mod :reverse-line))]
        (if (= (type f) "function")
            (set cur (or (f cur ctx) cur))
            (set cur nil))))
    cur))

(fn reverse-file-group
  [meta lines ctx]
  (let [chain (vim.deepcopy (or (. meta :transform-chain) []))
        out nil]
    (var cur out)
    (for [i (# chain) 1 -1]
      (let [mod (module-by-name (. chain i))
            f (and mod (. mod :reverse-file))]
        (if (= (type f) "function")
            (set cur (f (or cur lines) ctx))
            (set cur nil))))
    cur))

(fn M.reverse-group
  [meta lines ctx]
  "Reverse one rendered logical group back to source form. Expected output: {:kind :replace :text \"...\"} or {:kind :rewrite-bytes :bytes \"...\"}."
  (let [kind (or (. meta :source-group-kind) "line")
        chain (or (. meta :transform-chain) [])]
    (if (= kind "file")
        (let [blob (reverse-file-group meta lines ctx)]
          (if blob
              {:kind :rewrite-bytes :bytes blob}
              {:error "non-reversible file transform"}))
        (let [collapsed (if (> (# chain) 0)
                            (reverse-line-group meta lines ctx)
                            [(table.concat (or lines []) "")])]
          (if (and collapsed (= (# collapsed) 1))
              {:kind :replace :text (or (. collapsed 1) "")}
              {:error "non-reversible line transform"})))))

(fn M.apply-view
  [path raw-lines ctx]
  (let [flags (or (and ctx ctx.transforms) {})
        wrap-width (and ctx (. ctx :wrap-width))
        linebreak? (if (= (and ctx (. ctx :linebreak)) nil) true (clj.boolean (. ctx :linebreak)))
        file-view0 nil]
    (var file-view1 file-view0)
    (each [_ mod (ipairs (modules))]
      (when (and (not file-view1)
                 (. flags (module-key mod))
                 (= (type (. mod :should-apply-file?)) "function")
                 (= (type (. mod :apply-file)) "function")
                 ((. mod :should-apply-file?) path raw-lines ctx))
        (let [produced ((. mod :apply-file) path raw-lines ctx)]
          (when (and (= (type produced) "table") (> (# produced) 0))
            (set file-view1 (file-view (limited-lines produced) (module-key mod)))))))
    (let [view0 (or file-view1
                    (let [view (identity-view raw-lines)]
                      (var current view)
                      (each [_ mod (ipairs (modules))]
                        (when (and (. flags (module-key mod))
                                   (= (type (. mod :should-apply-line?)) "function")
                                   (= (type (. mod :apply-line)) "function"))
                          (set current (apply-line-transform current mod ctx))))
                      current))]
      (if (and wrap-width (> wrap-width 0))
          (wrap-view view0 wrap-width linebreak?)
          view0))))

(fn M.active-names
  [flags]
  "Return enabled transform names. Expected output: [\"hex\" \"json\"]."
  (let [out []]
    (each [_ mod (ipairs (modules))]
      (let [name (module-key mod)]
        (when (. (or flags {}) name)
          (table.insert out name))))
    out))

M
