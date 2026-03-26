(import-macros {: when-let : when-not : cond} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local file-source (require :metabuffer.source.file))
(local lgrep-source (require :metabuffer.source.lgrep))
(local scope-directives (require :metabuffer.query.scope))
(local transform-directives (require :metabuffer.transform))
(local prompt-directives (require :metabuffer.query.prompt_directives))

(local M {})

(local directive-providers
  [{:type "option" :provider prompt-directives}
   {:type "scope" :provider scope-directives}
   {:type "transform" :provider transform-directives}
   {:type "source" :provider file-source}
   {:type "source" :provider lgrep-source}])

(fn split-directive-name
  [name]
  (let [txt (or name "")
        stem (or (string.match txt "^([^:]+)") txt)
        suffix (or (string.match txt "(:.+)$") "")]
    [stem suffix]))

(fn provider-specs
  []
  (let [out []]
    (each [provider-idx entry (ipairs directive-providers)]
      (let [provider (. entry :provider)
            provider-type (. entry :type)
            [ok raw] (if (= (type (. provider :query-directive-specs)) "function")
                         [(pcall (. provider :query-directive-specs))]
                         [true (or (. provider :query-directive-specs) [])])
            specs (if (and ok (= (type raw) "table")) raw [])]
        (each [spec-idx spec (ipairs specs)]
          (table.insert out (vim.tbl_extend "force"
                                            spec
                                            {:provider-type provider-type
                                             :provider-idx provider-idx
                                             :spec-idx spec-idx})))))
    out))

(fn resolve-short-stems
  []
  (let [used {}
        entries {}]
    (each [_ spec (ipairs (provider-specs))]
      (when-let [long-name (. spec :long)]
        (let [[stem] (split-directive-name long-name)]
          (when (~= stem "")
            (when (not (. entries stem))
              (set (. entries stem) {:stem stem
                                     :provider-idx (. spec :provider-idx)
                                     :spec-idx (. spec :spec-idx)}))))))
    (let [ordered []]
      (each [_ entry (pairs entries)]
        (table.insert ordered entry))
      (table.sort ordered
        (fn [a b]
          (if (= (or (. a :provider-idx) 0) (or (. b :provider-idx) 0))
              (< (or (. a :spec-idx) 0) (or (. b :spec-idx) 0))
              (< (or (. a :provider-idx) 0) (or (. b :provider-idx) 0)))))
      (let [shorts {}]
        (each [_ entry (ipairs ordered)]
          (let [stem (or (. entry :stem) "")]
            (for [len 1 (# stem)]
              (when (and (= (. shorts stem) nil)
                         (= (. used (string.sub stem 1 len)) nil))
                (let [prefix (string.sub stem 1 len)]
                  (set (. used prefix) true)
                  (set (. shorts stem) prefix))))
            (when (= (. shorts stem) nil)
              (set (. shorts stem) stem))))
        shorts))))

(fn all-specs
  []
  (let [out []]
    (let [short-stems (resolve-short-stems)]
      (each [_ spec (ipairs (provider-specs))]
        (let [long-name (or (. spec :long) "")
              [stem suffix] (split-directive-name long-name)
              resolved-short (if (~= stem "")
                               (.. (or (. short-stems stem) stem) suffix)
                               nil)]
          (table.insert out (vim.tbl_extend "force"
                                            spec
                                            {:short resolved-short})))))
    out))

(fn names-for-spec
  [spec]
  (let [out []
        short (or (. spec :short) "")
        long (or (. spec :long) "")]
    (when (~= short "")
      (table.insert out short))
    (when (~= long "")
      (table.insert out long))
    out))

(fn display-token
  [prefix spec]
  (let [name (or (. spec :short) (. spec :long) "")
        arg (or (. spec :arg) "")]
    (cond
      (= (or (. spec :kind) "") "literal") (or (. spec :literal) "")
      (= (or (. spec :kind) "") "prefix-value") (.. (or (. spec :prefix) "") arg)
      (= (or (. spec :kind) "") "suffix") (.. prefix name ":" arg)
      :else (.. prefix name (if (~= arg "") (.. " " arg) "")))))

(fn helptext
  [prefix spec]
  (let [long-name (or (. spec :long) "")
        short-name (or (. spec :short) "")
        label (cond
                (= (or (. spec :kind) "") "literal") (or (. spec :literal) "")
                (= (or (. spec :kind) "") "prefix-value") (.. (or (. spec :prefix) "") (or (. spec :arg) "{value}"))
                (= short-name "")
                (.. prefix long-name (if (= (or (. spec :arg) "") "") "" (.. " " (. spec :arg))))
                :else
                (.. prefix long-name
                    (if (= (or (. spec :arg) "") "") "" (.. " " (. spec :arg)))
                    " / "
                    prefix short-name
                    (if (= (or (. spec :arg) "") "") "" (.. " " (. spec :arg)))))
        doc (or (. spec :doc) "")]
    (vim.trim (.. label " — " doc))))

(fn statusline-label
  [spec]
  (let [override (. spec :statusline)
        name (or (. spec :long) "")
        [stem suffix] (split-directive-name name)
        await-mode (and (. spec :await) (. (. spec :await) :mode))
        stem-label (string.sub stem 1 (math.min 3 (# stem)))
        suffix-label (or (and (~= suffix "")
                              (> (# suffix) 1)
                              (string.sub suffix 2 2))
                         "")]
    (if (and (= (type override) "string") (~= override ""))
        override
        (if (and (= (and (. spec :await) (. (. spec :await) :kind)) "query-source")
                 (= (type await-mode) "string")
                 (~= await-mode ""))
            (.. (string.sub stem 1 (math.min 2 (# stem))) (string.sub await-mode 1 1))
            (if (= suffix-label "")
                stem-label
                (let [prefix-len (math.max 1 (math.min 2 (# stem-label)))]
                  (.. (string.sub stem-label 1 prefix-len) suffix-label)))))))

(fn status-group-key
  [spec]
  (let [kind (or (. spec :kind) "")
        await (and (. spec :await) (. spec :await :kind))]
    (if (or (= kind "toggle")
            (and (= kind "flag") (or (= (type (. spec :value)) "boolean")
                                     (~= (. spec :compat-key) nil))))
        (.. "state:" (or (. spec :compat-key) (. spec :token-key) (. spec :long) ""))
        (if (= await "query-source")
            (.. "source:" (or (. spec :long) ""))
            nil))))

(fn session-state-value
  [session spec]
  (let [parsed (or (and session session.last-parsed-query) {})
        token-key (or (. spec :token-key) "")
        compat-key (or (. spec :compat-key) "")
        effective-key (if (~= token-key "") (.. "effective-" token-key) "")
        parsed-v (and (~= token-key "") (. parsed token-key))
        compat-v (and (~= compat-key "") (. session compat-key))
        session-v (and (~= token-key "") (. session token-key))
        effective-v (and (~= effective-key "") (. session effective-key))]
    (if (~= parsed-v nil)
        parsed-v
        (if (~= compat-v nil)
            compat-v
            (if (~= effective-v nil)
                effective-v
                session-v)))))

(fn query-source-active?
  [session spec]
  (let [parsed (or (and session session.last-parsed-query) {})
        want-source (and (. spec :await) (. (. spec :await) :source-key))
        want-mode (and (. spec :await) (. (. spec :await) :mode))]
    (let [active? false]
      (var matched active?)
      (each [_ item (ipairs (or (. parsed :source-lines) []))]
        (when (and (not matched)
                   item
                   (= (or (. item :key) "") (or want-source ""))
                   (= (or (. item :kind) "") (or want-mode "")))
          (set matched true)))
      matched)))

(fn status-specs
  []
  (let [seen {}
        out []]
    (each [_ spec (ipairs (all-specs))]
      (let [group-key (status-group-key spec)]
        (when (and group-key (not (. seen group-key)))
          (set (. seen group-key) true)
          (table.insert out spec))))
    out))

(fn status-item-active?
  [session spec]
  (let [await-kind (and (. spec :await) (. (. spec :await) :kind))]
    (if (= await-kind "query-source")
        (query-source-active? session spec)
        (clj.boolean (session-state-value session spec)))))

(fn status-item-show?
  [spec active?]
  (let [provider-type (or (. spec :provider-type) "")]
    (if (= (and (. spec :await) (. (. spec :await) :kind)) "query-source")
        active?
        (if (or (= provider-type "transform")
                (= provider-type "source"))
            active?
            true))))

(fn M.statusline-items
  [session]
  "Return resolved statusline flag items from directive specs. Expected output: [{:label \"hid\" :active true}]."
  (let [out []]
    (each [_ spec (ipairs (status-specs))]
      (let [active? (status-item-active? session spec)]
        (when (status-item-show? spec active?)
          (table.insert out {:label (statusline-label spec)
                             :active active?
                             :provider-type (. spec :provider-type)
                             :kind (. spec :kind)
                             :long (. spec :long)}))))
    out))

(fn literal-token?
  [prefix tok name]
  (or (= tok (.. "#" name))
      (= tok (.. prefix name))))

(fn toggle-match
  [prefix tok spec]
  "Return parsed toggle directive match. Expected output: {:key :include-hidden :value true} or nil."
  (let [key (. spec :token-key)
        await (and (. spec :await-when-true) (. spec :await))
        found nil]
    (var out found)
    (each [_ name (ipairs (names-for-spec spec))]
      (when-not out
        (cond
          (or (literal-token? prefix tok name)
              (= tok (.. "+" name))
              (= tok (.. "#+" name)))
          (set out {:key key :value true :await await})

          (or (= tok (.. "-" name))
              (= tok (.. "#-" name)))
          (set out {:key key :value false})

          (or (literal-token? prefix tok (.. "no" name))
              (= tok (.. "#no" name)))
          (set out {:key key :value false}))))
    out))

(fn flag-match
  [prefix tok spec]
  "Return parsed fixed-value directive match. Expected output: {:key :history :value true} or nil."
  (let [out nil]
    (var parsed out)
    (each [_ name (ipairs (names-for-spec spec))]
      (when (and (not parsed)
                 (literal-token? prefix tok name))
        (set parsed {:key (. spec :token-key)
                     :value (. spec :value)
                     :await (. spec :await)})))
    parsed))

(fn suffix-match
  [prefix tok spec]
  "Return parsed suffix directive match. Expected output: {:key :save-tag :value \"quick\"} or nil."
  (let [out nil]
    (var parsed out)
    (each [_ name (ipairs (names-for-spec spec))]
      (when-not parsed
        (let [hash-name (.. "#" name ":")
              pref-name (.. prefix name ":")
              matched (or (string.match tok (.. "^" (vim.pesc hash-name) "(.+)$"))
                          (string.match tok (.. "^" (vim.pesc pref-name) "(.+)$")))]
          (when-let [value matched]
            (let [trimmed (if (. spec :trim-value)
                              (vim.trim value)
                              value)]
              (when (~= trimmed "")
                (set parsed {:key (. spec :token-key)
                             :value trimmed})))))))
    parsed))

(fn prefix-value-match
  [tok spec]
  "Return parsed prefix-value directive match. Expected output: {:key :saved-tag :value \"tag\"} or nil."
  (let [prefix0 (or (. spec :prefix) "")
        matched (string.match tok (.. "^" (vim.pesc prefix0) "(.+)$"))]
    (when-let [value matched]
      (let [trimmed (if (. spec :trim-value)
                        (vim.trim value)
                        value)]
        (when (~= trimmed "")
          {:key (. spec :token-key)
           :value trimmed})))))

(fn parse-directive-token
  [prefix tok spec]
  "Return parsed directive token according to spec. Expected output: {:key :lazy :value true} or nil."
  (let [kind (or (. spec :kind) "flag")]
    (cond
      (= kind "toggle") (toggle-match prefix tok spec)
      (= kind "flag") (flag-match prefix tok spec)
      (= kind "suffix") (suffix-match prefix tok spec)
      (= kind "prefix-value") (prefix-value-match tok spec)
      (= kind "literal")
      (if (= tok (or (. spec :literal) ""))
          {:key (. spec :token-key) :value (. spec :value)}
          nil)
      :else nil)))

(fn M.parse-token
  [prefix tok]
  "Return parsed query directive metadata for one token. Expected output: {:key :include-files :value true :await {:kind \"file\"}}."
  (let [out nil]
    (var parsed out)
    (each [_ spec (ipairs (all-specs))]
      (when-not parsed
        (when-let [parsed-token (parse-directive-token prefix tok spec)]
          (set parsed (vim.tbl_extend "force" parsed-token spec)))))
    parsed))

(fn M.catalog
  [prefix]
  "Return resolved directive metadata with derived names and help text."
  (let [out []]
    (each [_ spec (ipairs (all-specs))]
      (table.insert out
                    (vim.tbl_extend "force"
                                    spec
                                    {:display (display-token prefix spec)
                                     :help (helptext prefix spec)})))
    out))

(fn M.matching-catalog
  [prefix token]
  "Return directive catalog entries matching a partial token."
  (let [needle (or token "")
        out []]
    (each [_ spec (ipairs (M.catalog prefix))]
      (let [display (or (. spec :display) "")
            long-token (display-token prefix (vim.tbl_extend "force" spec {:short (. spec :long)}))]
        (when (or (= needle "")
                  (vim.startswith display needle)
                  (and (~= long-token "") (vim.startswith long-token needle))
                  (and (. spec :literal) (vim.startswith (. spec :literal) needle))
                  (and (. spec :prefix) (vim.startswith (. spec :prefix) needle)))
          (table.insert out spec))))
    out))

(fn M.complete-items
  [prefix token]
  "Return completion items for a directive token prefix."
  (let [out []]
    (each [_ spec (ipairs (M.matching-catalog prefix token))]
      (table.insert out {:word (. spec :display)
                         :abbr (. spec :display)
                         :menu (.. "[" (or (. spec :provider-type) "directive") "]")
                         :info (. spec :help)}))
    out))

(fn token-span
  [line col1]
  (let [txt (or line "")
        cursor (math.max 1 (math.min (+ (# txt) 1) (or col1 1)))
        left (string.sub txt 1 (math.max 0 (- cursor 1)))
        start (string.match left "()%S+$")]
    (when start
      (let [finish0 (or (string.find txt "%s" start) (+ (# txt) 1))
            finish (if finish0 (math.max start (- finish0 1)) (# txt))]
        {:start start
         :finish finish
         :token (string.sub txt start finish)}))))

(fn M.token-under-cursor
  [line col1]
  "Return token span at the prompt cursor. Expected output: {:start 1 :finish 3 :token \"#lg\"}."
  (token-span line col1))

(fn option-prefix
  []
  (let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
        p
        "#")))

(fn M.completefunc
  [findstart base]
  "Builtin completefunc for directive completion."
  (let [line (vim.api.nvim_get_current_line)
        col1 (+ (or (. (vim.api.nvim_win_get_cursor 0) 2) 0) 1)
        span (token-span (line) col1)]
    (if (= findstart 1)
        (if span
            (- (. span :start) 1)
            -2)
        (if (and span
                 (vim.startswith (or (. span :token) "") (option-prefix)))
            (M.complete-items (option-prefix) (or base ""))
            []))))

(fn M.query-state-init
  []
  "Return generic directive parse state defaults."
  (let [out {}]
    (each [_ spec (ipairs (all-specs))]
      (let [key (. spec :token-key)]
        (when (and key (= (. out key) nil))
          (set (. out key) nil))))
    out))

(fn M.all-specs
  []
  "Return the full resolved directive spec list.
   Each spec has :token-key, :kind, :provider-type, :long, :short, etc."
  (all-specs))

(fn M.finalize-parsed!
  [parsed]
  "Decorate parsed state with compat aliases declared by directive specs."
  (each [_ spec (ipairs (all-specs))]
    (let [key (. spec :token-key)
          compat-key (. spec :compat-key)]
      (when (and key compat-key)
        (set (. parsed compat-key) (. parsed key)))))
  parsed)

(fn M.query-compat-view
  [parsed]
  "Return generic directive compatibility view for parse-query-text."
  (let [out {}]
    (each [_ spec (ipairs (all-specs))]
      (let [key (. spec :token-key)
            compat-key (. spec :compat-key)]
        (when key
          (set (. out key) (. parsed key)))
        (when (and key compat-key)
          (set (. out compat-key) (. parsed compat-key)))))
    out))

(fn M.empty-query-compat-view
  []
  "Return empty generic directive compatibility view."
  (let [out {}]
    (each [_ spec (ipairs (all-specs))]
      (let [key (. spec :token-key)
            compat-key (. spec :compat-key)]
        (when key
          (set (. out key) nil))
        (when compat-key
          (set (. out compat-key) nil))))
    out))

M
