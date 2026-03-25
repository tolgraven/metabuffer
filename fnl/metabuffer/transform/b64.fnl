(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))

(local M {})

(set M.transform-key "b64")
(set M.query-directive-specs
     [{:kind "toggle"
       :long "b64"
       :token-key :include-b64
       :doc "Decode obvious base64 text before display and filtering."
       :compat-key :b64}])

(local alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

(fn decode-base64
  [txt]
  (if (and vim.base64 (= (type (. vim.base64 :decode)) "function"))
      (let [[ok decoded] [(pcall vim.base64.decode txt)]]
        (if ok decoded nil))
      (let [clean (string.gsub (or txt "") "%s+" "")
            out []
            chunk0 0
            bits0 0
            valid?0 true]
        (var chunk chunk0)
        (var bits bits0)
        (var valid? valid?0)
        (for [i 1 (# clean)]
          (let [ch (string.sub clean i i)]
            (when-not (= ch "=")
              (let [idx (string.find alphabet ch 1 true)]
                (if idx
                    (do
                      (set chunk (+ (* chunk 64) (- idx 1)))
                      (set bits (+ bits 6))
                      (while (>= bits 8)
                        (set bits (- bits 8))
                        (table.insert out (string.char (% (math.floor (/ chunk (^ 2 bits))) 256)))))
                    (set valid? false))))))
        (if valid? (table.concat out) nil))))

(fn obvious-base64-token
  [line]
  (let [trimmed (vim.trim (or line ""))
        quoted (or (string.match trimmed "^\"([A-Za-z0-9+/=_-]+)\"$")
                   (string.match trimmed "^'([A-Za-z0-9+/=_-]+)'$"))
        token (or quoted trimmed)]
    (when (and (>= (# token) 8)
               (= 0 (% (# token) 4))
               (not= nil (string.match token "^[A-Za-z0-9+/=_-]+$")))
      token)))

(fn printable-ratio
  [s]
  (let [txt (or s "")
        n (# txt)]
    (if (= n 0)
        0
        (let [score0 0]
          (var score score0)
          (for [i 1 n]
            (let [b (string.byte txt i)]
              (when (or (= b 9) (= b 10) (= b 13) (and (>= b 32) (< b 127)))
                (set score (+ score 1)))))
          (/ score n)))))

(fn M.should-apply-line?
  [line _ctx]
  (clj.boolean (obvious-base64-token line)))

(fn M.apply-line
  [line _ctx]
  (when-let [token (obvious-base64-token line)]
    (let [max-runs 3
          current token
          last-decoded nil]
      (var cur current)
      (var out last-decoded)
      (for [_ 1 max-runs]
        (when cur
          (let [decoded (decode-base64 cur)]
            (if (and decoded (>= (printable-ratio decoded) 0.9))
                (do
                  (set out decoded)
                  (set cur (obvious-base64-token decoded)))
                (set cur nil)))))
      (when (and out (~= out ""))
        (vim.split out "\n" {:plain true :trimempty false})))))

(fn encode-base64
  [txt]
  (if (and vim.base64 (= (type (. vim.base64 :encode)) "function"))
      (let [[ok encoded] [(pcall vim.base64.encode txt)]]
        (if ok encoded nil))
      (let [bytes [(string.byte (or txt "") 1 -1)]
            out []
            n (# bytes)]
        (for [i 1 n 3]
          (let [b1 (or (. bytes i) 0)
                b2 (or (. bytes (+ i 1)) 0)
                b3 (or (. bytes (+ i 2)) 0)
                chunk (+ (* b1 65536) (* b2 256) b3)
                c1 (+ 1 (math.floor (/ chunk 262144)))
                c2 (+ 1 (% (math.floor (/ chunk 4096)) 64))
                c3 (+ 1 (% (math.floor (/ chunk 64)) 64))
                c4 (+ 1 (% chunk 64))
                rem (- n i -1)]
            (table.insert out (string.sub alphabet c1 c1))
            (table.insert out (string.sub alphabet c2 c2))
            (table.insert out (if (>= rem 2) (string.sub alphabet c3 c3) "="))
            (table.insert out (if (>= rem 3) (string.sub alphabet c4 c4) "="))))
        (table.concat out))))

(fn M.reverse-line
  [lines _ctx]
  (let [decoded (table.concat (or lines []) "\n")
        encoded (encode-base64 decoded)]
    (and encoded [encoded])))

M
