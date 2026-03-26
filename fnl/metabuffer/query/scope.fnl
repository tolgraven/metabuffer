(local M {})

(set M.query-directive-specs
     [{:kind "toggle"
       :long "hidden"
       :token-key :include-hidden
       :doc "Include hidden paths."
       :compat-key :hidden}
      {:kind "toggle"
       :long "ignored"
       :token-key :include-ignored
       :doc "Include ignored paths."
       :compat-key :ignored}
      {:kind "toggle"
       :long "deps"
       :token-key :include-deps
       :doc "Include dependency and vendor paths."
       :compat-key :deps}
      {:kind "toggle"
       :long "binary"
       :token-key :include-binary
       :doc "Include binary files."
       :compat-key :binary}])

M
