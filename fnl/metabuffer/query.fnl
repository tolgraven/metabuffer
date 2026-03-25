(import-macros {: when-let
                 : if-let
                 : when-some
                 : if-some
                 : when-not
                 : cond}
  :io.gitlab.andreyorst.cljlib.core)
(local directive-mod (require :metabuffer.query.directive))
(local source-mod (require :metabuffer.source))
(local M {})

(fn M.truthy?
  [v]
  "Public API: M.truthy?."
  (or (= v true) (= v 1) (= v "1") (= v "true")))

(fn option-prefix
  []
  (if-let [p (. vim.g "meta#prefix")]
    (if (and (= (type p) "string") (~= p ""))
      p
      "#")
    "#"))

(fn tokenize-line
  [line]
  "Split one prompt line into tokens while preserving quoted spans. Expected output: [\"#lg\" \"\\\"setup path\\\"\" \"rest\"]."
  (let [s (or line "")
        n (# s)
        out []
        cur0 []
        quote-char0 nil]
    (var cur cur0)
    (var quote-char quote-char0)
    (local flush!
      (fn []
        (when (> (# cur) 0)
          (table.insert out (table.concat cur))
          (set cur []))))
    (var i 1)
    (while (<= i n)
      (let [ch (string.sub s i i)]
        (if quote-char
            (do
              (table.insert cur ch)
              (when (= ch quote-char)
                (set quote-char nil)))
            (if (or (= ch "\"") (= ch "'"))
                (do
                  (table.insert cur ch)
                  (set quote-char ch))
                (if (string.match ch "%s")
                    (flush!)
                    (table.insert cur ch)))))
      (set i (+ i 1)))
    (flush!)
    out))

(fn parse-option-token
  [tok]
  (let [prefix (option-prefix)
        parsed (directive-mod.parse-token prefix tok)]
    (when parsed
      [(. parsed :key) (. parsed :value) (. parsed :await)])))

(fn escaped-prefix-token
  [tok]
  (let [t (or tok "")
        prefix (option-prefix)
        escaped-prefix (.. "\\" prefix)]
    (if (and (> (# t) (# escaped-prefix))
             (vim.startswith t escaped-prefix))
      (string.sub t 2)
      nil)))

(fn prefix-directive-token?
  [tok]
  (let [t (or tok "")
        prefix (option-prefix)]
    (and (~= t prefix)
         (vim.startswith t prefix))))

(fn assoc-option
  [acc k v]
  (let [next (vim.deepcopy acc)]
    (set (. next k) v)
    next))

(fn unquote-token
  [tok]
  (let [t (or tok "")
        n (# t)]
    (if (>= n 2)
      (let [lead (string.sub t 1 1)
            tail (string.sub t n n)]
        (if (or (and (= lead "\"") (= tail "\""))
                (and (= lead "'") (= tail "'")))
          (string.sub t 2 (- n 1))
          t))
      t)))

(fn apply-awaited-directive
  [state tok]
  "Consume one awaited directive argument token. Expected output: updated parser state."
  (let [directive (. state :await-directive)
        arg (unquote-token tok)]
    (source-mod.apply-awaited-directive state directive arg)))

(fn parse-parts
  [parts idx state]
  (if (> idx (# parts))
    state
    (let [tok (. parts idx)]
        (if-let [escaped (escaped-prefix-token tok)]
        (let [next (vim.deepcopy state)]
          (table.insert (. next :keep) escaped)
          (parse-parts parts (+ idx 1) next))
        (if-let [shortcut (source-mod.parse-bare-token state tok unquote-token)]
          (parse-parts parts (+ idx 1) shortcut)
          (if-let [parsed (parse-option-token tok)]
            (let [next (source-mod.apply-parsed-directive state (. parsed 1) (. parsed 2) (. parsed 3))]
              (parse-parts parts (+ idx 1) next))
              (if (prefix-directive-token? tok)
              (parse-parts parts (+ idx 1) state)
              (if (and (. state :await-directive) (~= (vim.trim tok) ""))
                  (parse-parts parts (+ idx 1) (apply-awaited-directive state tok))
                  (if-let [next (source-mod.consume-pending-token state tok unquote-token)]
                      (parse-parts parts (+ idx 1) next)
                      (let [next (vim.deepcopy state)]
                        (table.insert (. next :keep) tok)
                        (parse-parts parts (+ idx 1) next)))))))))))

(fn parse-line
  [acc line]
  (let [trimmed (vim.trim (or line ""))]
    (if (= trimmed "")
      (let [next (vim.deepcopy acc)]
        (table.insert (. next :lines) "")
        (table.insert (. next :source-lines) nil)
        next)
      (let [parts (tokenize-line trimmed)
            state (parse-parts
                    parts
                    1
                    (-> (assoc-option acc :keep [])
                        (assoc-option :line-source nil)
                        (assoc-option :await-directive nil)))
            next (vim.deepcopy state)]
        (table.insert (. next :lines) (table.concat (. state :keep) " "))
        (table.insert (. next :source-lines) (. state :line-source))
        (set (. next :keep) nil)
        (set (. next :line-source) nil)
        (set (. next :await-directive) nil)
        next))))

(fn parse-lines
  [lines idx state]
  (if (> idx (# lines))
    state
    (parse-lines lines (+ idx 1) (parse-line state (. lines idx)))))

(fn M.parse-query-lines
  [lines]
  "Public API: M.parse-query-lines."
  (let [init (vim.tbl_extend "force"
                             {:lines []}
                             (directive-mod.query-state-init)
                             (source-mod.query-state-init))]
    (let [parsed (parse-lines (or lines []) 1 init)]
      (directive-mod.finalize-parsed! parsed)
      (source-mod.finalize-parsed! parsed))))

(fn M.parse-query-text
  [query]
  "Public API: M.parse-query-text."
  (if (and (= (type query) "string") (~= query ""))
    (let [lines (vim.split query "\n" {:plain true})
          parsed (M.parse-query-lines lines)
          out {:query (table.concat (. parsed :lines) "\n")
               :lines (or (. parsed :lines) [])
               :source-lines (or (. parsed :source-lines) [])}]
      (vim.tbl_extend
        "force"
        (vim.tbl_extend "force" out (directive-mod.query-compat-view parsed))
        (source-mod.query-compat-view parsed)))
    (let [out {:query query
               :lines (if (and (= (type query) "string") (~= query ""))
                          (vim.split query "\n" {:plain true})
                          [])
               :source-lines []}]
      (vim.tbl_extend
        "force"
        (vim.tbl_extend "force" out (directive-mod.empty-query-compat-view))
        (source-mod.empty-query-compat-view)))))

(fn M.apply-default-source
  [parsed enabled?]
  "Promote the first token on each non-empty line into the default query source when enabled. Expected output: parsed query table."
  (let [next (source-mod.apply-default-query-source parsed enabled? tokenize-line)]
    (set (. next :query) (table.concat (or (. next :lines) []) "\n"))
    next))

(fn lines-has-active?
  [lines idx]
  (if (> idx (# lines))
    false
    (or (~= (vim.trim (or (. lines idx) "")) "")
        (lines-has-active? lines (+ idx 1)))))

(fn M.query-lines-has-active?
  [lines]
  "Public API: M.query-lines-has-active?."
  (lines-has-active? (or lines []) 1))

(set M.tokenize-line tokenize-line)

M
