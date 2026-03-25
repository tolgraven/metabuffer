(import-macros {: if-let} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local text (require :metabuffer.source.text))
(local file (require :metabuffer.source.file))
(local lgrep (require :metabuffer.source.lgrep))

(local M {})

(local query-sources [{:key "lgrep" :provider lgrep}])

(fn query-source-provider
  [key]
  (let [found nil]
    (var out found)
    (each [_ entry (ipairs query-sources)]
      (when (and (not out) (= (. entry :key) key))
        (set out (. entry :provider))))
    out))
(fn query-source-entry
  [parsed]
  (when parsed
    (let [found nil]
      (var out found)
      (each [_ entry (ipairs query-sources)]
        (let [provider (. entry :provider)
              active? (. provider :active?)]
          (when (and (not out)
                     (= (type active?) "function")
                     (active? parsed))
            (set out entry))))
      out)))

(fn M.provider-for-ref
  [ref]
  (if (= (or (and ref ref.kind) "") "file-entry")
      file
      (= (or (and ref ref.kind) "") "lgrep-hit")
      lgrep
      text))

(fn M.query-state-init
  []
  "Return source-related parse state defaults. Expected output: {:source-lines [] ...}."
  {:source-lines []
   :lgrep-lines []
   :include-files nil
   :files nil
   :file-lines []
   :file-await-token false
   :line-source nil
   :await-directive nil})

(fn M.parse-bare-token
  [state tok unquote-token]
  "Allow source providers to consume non-prefixed shortcut tokens. Expected output: updated state or nil."
  (let [f (. file :parse-bare-token)]
    (if (= (type f) "function")
        (f state tok unquote-token)
        nil)))

(fn M.apply-parsed-directive
  [state key value await]
  "Apply parsed directive metadata and any source-specific pending state. Expected output: updated parser state."
  (let [next (vim.deepcopy state)]
    (set (. next key) value)
    (when (and await (not (= value false)))
      (set (. next :await-directive) await)
      (when (= (. await :kind) "file")
        (set (. next :file-await-token) true)))
    next))

(fn M.apply-awaited-directive
  [state directive arg]
  "Apply one awaited source directive argument. Expected output: updated parser state."
  (let [next (vim.deepcopy state)
        kind (and directive (. directive :kind))]
    (if (= kind "file")
        (do
          (table.insert (. next :file-lines) arg)
          (set (. next :file-await-token) false))
        (= kind "query-source")
        (set (. next :line-source)
             {:key (or (. directive :source-key) "")
              :kind (or (. directive :mode) "search")
              :query arg}))
    (set (. next :await-directive) nil)
    next))

(fn source-lines-for-key
  [parsed key]
  (let [out []]
    (each [_ spec (ipairs (or (. parsed :source-lines) []))]
      (if (and spec (= (or (. spec :key) "") key))
          (table.insert out {:kind (or (. spec :kind) "search")
                             :query (or (. spec :query) "")})
          (table.insert out nil)))
    out))

(fn M.finalize-parsed!
  [parsed]
  "Decorate generic parsed query state with source compatibility fields."
  (set (. parsed :files) (. parsed :include-files))
  (set (. parsed :lgrep-lines) (source-lines-for-key parsed "lgrep"))
  parsed)

(fn M.consume-pending-token
  [state tok unquote-token]
  "Consume any pending source-specific followup token. Expected output: updated state or nil."
  (when (and (. state :file-await-token) (~= (vim.trim (or tok "")) ""))
    (let [next (vim.deepcopy state)]
      (table.insert (. next :file-lines) (unquote-token tok))
      (set (. next :file-await-token) false)
      next)))

(fn M.query-compat-view
  [parsed]
  "Return source compatibility fields for query parsing. Expected output: {:lgrep-lines [...] :include-files true}."
  {:lgrep-lines (or (. parsed :lgrep-lines) [])
   :include-files (. parsed :include-files)
   :file-lines (or (. parsed :file-lines) [])})

(fn M.empty-query-compat-view
  []
  "Return empty source compatibility fields. Expected output: {:lgrep-lines [] :include-files nil :file-lines []}."
  {:lgrep-lines []
   :include-files nil
   :file-lines []})

(fn M.apply-default-query-source
  [parsed enabled? tokenize-line]
  "Promote the first token on each non-empty line into the default query source. Expected output: parsed query table."
  (let [provider (query-source-provider "lgrep")
        active? (. provider :active?)]
    (if (or (not enabled?)
            (and (= (type active?) "function")
                 (active? parsed)))
        parsed
        (let [next (vim.deepcopy (or parsed {}))
              out-lines []
              out-source []]
          (each [_ line (ipairs (or (. next :lines) []))]
            (let [tokens (tokenize-line (or line ""))]
              (if (> (# tokens) 0)
                  (let [first (. tokens 1)
                        rest []]
                    (for [i 2 (# tokens)]
                      (table.insert rest (. tokens i)))
                    (table.insert out-source {:key "lgrep" :kind "search" :query first})
                    (table.insert out-lines (table.concat rest " ")))
                  (do
                    (table.insert out-source nil)
                    (table.insert out-lines "")))))
          (set (. next :lines) out-lines)
          (set (. next :source-lines) out-source)
          (M.finalize-parsed! next)))))

(fn M.hit-prefix
  [ref]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :hit-prefix) ref)))

(fn M.info-path
  [ref full-path?]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :info-path) ref full-path?)))

(fn M.info-suffix
  [session ref mode read-file-lines-cached read-file-view-cached]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :info-suffix) session ref mode read-file-lines-cached read-file-view-cached)))

(fn M.info-meta
  [session ref]
  (let [provider (M.provider-for-ref ref)
        f (. provider :info-meta)]
    (if (= (type f) "function")
        (f session ref)
        nil)))

(fn M.info-view
  [session ref ctx]
  (let [provider (M.provider-for-ref ref)
        f (. provider :info-view)
        mode (or (and ctx ctx.mode) "meta")
        read-file-lines-cached (and ctx ctx.read-file-lines-cached)
        read-file-view-cached (and ctx ctx.read-file-view-cached)]
    (if (= (type f) "function")
        (f session ref ctx)
        {:path (M.info-path ref false)
         :icon-path (M.info-path ref false)
         :show-icon true
         :highlight-dir true
         :highlight-file true
         :sign {:text "  " :hl "LineNr"}
         :suffix (M.info-suffix session ref mode read-file-lines-cached read-file-view-cached)
         :suffix-prefix "  "
         :suffix-highlights []})))

(fn M.preview-filetype
  [ref]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :preview-filetype) ref)))

(fn M.preview-lines
  [session ref height read-file-lines-cached read-file-view-cached]
  (let [provider (M.provider-for-ref ref)]
    ((. provider :preview-lines) session ref height read-file-lines-cached read-file-view-cached)))

(fn M.query-source-key
  [parsed]
  "Return active query-backed source key. Expected output: \"lgrep\"."
  (let [entry (query-source-entry parsed)]
    (and entry (. entry :key))))

(fn M.query-source-active?
  [parsed]
  "Return true when a query-backed source is active. Expected output: true."
  (clj.boolean (M.query-source-key parsed)))

(fn M.query-source-signature
  [parsed]
  "Return stable query-backed source signature. Expected output: \"lgrep:search:setup\"."
  (if-let [entry (query-source-entry parsed)]
    (let [provider (. entry :provider)
          f (. provider :signature)
          sig (if (= (type f) "function") (f parsed) "")]
      (if (~= sig "")
          (.. (. entry :key) ":" sig)
          (. entry :key)))
    ""))

(fn M.query-source-debounce-ms
  [settings parsed]
  "Return debounce floor for active query-backed source. Expected output: 260."
  (if-let [entry (query-source-entry parsed)]
    (let [provider (. entry :provider)
          f (. provider :debounce-ms)]
      (if (= (type f) "function")
          (f settings parsed)
          0))
    0))

(fn M.collect-query-source-set
  [settings parsed canonical-path]
  "Collect content/refs from active query-backed source. Expected output: {:content [...] :refs [...]} or nil."
  (if-let [entry (query-source-entry parsed)]
    (let [provider (. entry :provider)
          f (. provider :collect-source-set)]
      (if (= (type f) "function")
          (f settings parsed canonical-path)
          nil))
    nil))

(fn M.provider-for-op
  [op]
  (if (= (or (and op op.ref-kind) "") "file-entry")
      file
      text))

(fn M.apply-write-ops!
  [ops]
  (let [grouped {}]
    (each [_ op (ipairs (or ops []))]
      (let [provider (M.provider-for-op op)
            key (or (. provider :provider-key) "text")
            bucket (or (. grouped key) {:provider provider :ops {}})
            bucket-ops (. bucket :ops)
            path (or (. op :path) "")
            per-path (or (. bucket-ops path) [])]
        (table.insert per-path op)
        (set (. bucket-ops path) per-path)
        (set (. grouped key) bucket)))
    (let [result {:wrote false :changed 0 :post-lines {} :paths {} :renames {}}
          post-lines (. result :post-lines)
          paths (. result :paths)
          renames (. result :renames)]
      (each [_ bucket (pairs grouped)]
        (let [provider (. bucket :provider)
              f (. provider :apply-write-ops!)
              part (if (= (type f) "function")
                       (f (. bucket :ops))
                       {:wrote false :changed 0 :post-lines {} :paths {} :renames {}})]
          (when (. part :wrote)
            (set (. result :wrote) true))
          (set (. result :changed) (+ (. result :changed) (or (. part :changed) 0)))
          (each [path lines (pairs (or (. part :post-lines) {}))]
            (set (. post-lines path) lines))
          (each [path v (pairs (or (. part :paths) {}))]
            (set (. paths path) v))
          (each [old-path new-path (pairs (or (. part :renames) {}))]
            (set (. renames old-path) new-path))))
      result)))

M
