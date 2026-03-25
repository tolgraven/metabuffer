(local M {})

(set M.query-directive-specs
     [{:kind "toggle"
       :long "prefilter"
       :token-key :prefilter
       :doc "Enable project lazy prefiltering."
       :compat-key :prefilter}
      {:kind "flag"
       :long "escape"
       :token-key :prefilter
       :value false
       :doc "Disable prefiltering."
       :compat-key :prefilter}
      {:kind "toggle"
       :long "lazy"
       :token-key :lazy
       :doc "Enable lazy project loading."
       :compat-key :lazy}
      {:kind "suffix"
       :long "exp"
       :token-key :expansion
       :arg "{expander}"
       :doc "Set the active expansion mode."
       :compat-key :expansion
       :trim-value true}
      {:kind "flag"
       :long "history"
       :token-key :history
       :doc "Merge persisted history into the current session."
       :compat-key :history
       :value true}
      {:kind "suffix"
       :long "save"
       :token-key :save-tag
       :arg "{tag}"
       :doc "Save the current prompt under a tag."
       :compat-key :save-tag
       :trim-value true}
      {:kind "literal"
       :long "saved-browser"
       :literal "##"
       :token-key :saved-browser
       :doc "Open the saved-prompt browser."
       :compat-key :saved-browser
       :value true}
      {:kind "prefix-value"
       :long "saved-tag"
       :prefix "##"
       :token-key :saved-tag
       :arg "{tag}"
       :doc "Restore a saved prompt inline."
       :compat-key :saved-tag
       :trim-value true}])

M
