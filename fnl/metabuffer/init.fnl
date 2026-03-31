(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local router (require :metabuffer.router))
(local config (require :metabuffer.config))
(local events (require :metabuffer.events))
(local compat-providers (require :metabuffer.compat))
(local core-events-provider (require :metabuffer.core_events))
(local PRIMARY_LINE_GROUPS ["Title" "String" "Number" "Special" "Type" "Identifier"])

(local M {})
(local PATH_SEG_GROUPS
  ["Directory" "Identifier" "Type" "Special" "String" "Constant" "Function" "Statement"
   "PreProc" "Keyword" "Operator" "Character" "Tag" "Delimiter" "Number" "Boolean"
   "Macro" "Title" "Question" "Exception" "DiffAdd" "DiffChange" "DiffText" "DiagnosticInfo"])
(local AUTHOR_GROUPS
  ["Identifier" "Type" "Special" "String" "Constant" "Function" "Statement" "PreProc"
   "Keyword" "Operator" "Character" "Tag" "Delimiter" "Number" "Boolean" "Macro"
   "Title" "Question" "Exception" "DiffAdd" "DiffChange" "DiffText" "DiagnosticInfo" "DiagnosticHint"])

(fn rgb-luma
  [n]
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)]
        (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b)))))

(fn hl-rendered-fg
  [hl]
  (if (and hl (. hl :reverse))
      (or (. hl :bg) (. hl :fg))
      (. hl :fg)))

(fn hl-rendered-bg
  [hl]
  (if (and hl (. hl :reverse))
      (or (. hl :fg) (. hl :bg))
      (. hl :bg)))

(var meta-statusline-bg nil)
(var meta-preview-statusline-bg nil)
(var refresh-augroup nil)
(var last-setup-opts nil)

(fn statusline-color-from
  [group]
  (let [opts {:reverse false :cterm {:reverse false}}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        [ok-sl sl] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
        [ok-normal normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]]
    (when (and ok (= (type hl) "table"))
      (let [fg (. hl :fg)
            cfg (. hl :ctermfg)]
      (if fg
          (set (. opts :fg) fg)
          (when (and ok-sl (= (type sl) "table"))
            (set (. opts :fg) (hl-rendered-fg sl))))
      (if cfg
          (set (. opts :ctermfg) cfg)
          (when (and ok-sl (= (type sl) "table"))
            (set (. opts :ctermfg) (. sl :ctermfg))))
      (when (. hl :bold)
        (set (. opts :bold) (. hl :bold)))))
    (set (. opts :bg) (meta-statusline-bg))
    (set (. opts :ctermbg) (or (and ok-sl (= (type sl) "table") (. sl :ctermbg))
                               (and ok-normal (= (type normal) "table") (. normal :ctermbg))
                               0))
    (when-not (. opts :fg)
      (set (. opts :fg) (or (and ok-sl (= (type sl) "table") (hl-rendered-fg sl))
                            0xFFFFFF)))
    (when-not (. opts :ctermfg)
      (set (. opts :ctermfg) (or (and ok-sl (= (type sl) "table") (. sl :ctermfg))
                                 15)))
    opts))

(fn hit-hl
  [main-group curl-group]
  (let [opts {:default true :undercurl true}
        [ok-main main] [(pcall vim.api.nvim_get_hl 0 {:name main-group :link false})]
        [ok-curl curl] [(pcall vim.api.nvim_get_hl 0 {:name curl-group :link false})]]
    (when (and ok-main (= (type main) "table"))
      (when (. main :fg) (set (. opts :fg) (. main :fg)))
      (when (. main :bg) (set (. opts :bg) (. main :bg)))
      (when (. main :ctermfg) (set (. opts :ctermfg) (. main :ctermfg)))
      (when (. main :ctermbg) (set (. opts :ctermbg) (. main :ctermbg))))
    (when (and ok-curl (= (type curl) "table"))
      (if (. curl :sp)
          (set (. opts :sp) (. curl :sp))
          (when (. curl :fg) (set (. opts :sp) (. curl :fg)))))
    opts))

(fn hit-hl-primary
  [main-group curl-group]
  (let [opts (hit-hl main-group curl-group)]
    (set (. opts :default) true)
    opts))

(fn thin-underline-from
  [group]
  (let [opts {:default true :underdotted true :nocombine true}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (if (. hl :sp)
          (set (. opts :sp) (. hl :sp))
          (if (. hl :fg)
              (set (. opts :sp) (. hl :fg))
              (set (. opts :sp) 0xFF0000))))
    opts))

(fn plain-hl-from
  [group]
  (let [opts {:default true}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (when (hl-rendered-fg hl)
        (set (. opts :fg) (hl-rendered-fg hl)))
      (when (hl-rendered-bg hl)
        (set (. opts :bg) (hl-rendered-bg hl)))
      (when (. hl :ctermfg)
        (set (. opts :ctermfg) (. hl :ctermfg)))
      (when (. hl :ctermbg)
        (set (. opts :ctermbg) (. hl :ctermbg))))
    opts))

(fn fg-only-hl-from
  [group]
  (let [opts {:default true}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (when (hl-rendered-fg hl)
        (set (. opts :fg) (hl-rendered-fg hl)))
      (when (. hl :ctermfg)
        (set (. opts :ctermfg) (. hl :ctermfg))))
    opts))

(fn statusline-fg-hl-from
  [group]
  (let [opts {:reverse false :cterm {:reverse false}}
        [ok-hl hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        [ok-sl sl] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
        [ok-normal normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]]
    (set (. opts :fg) (or (and ok-hl (= (type hl) "table") (hl-rendered-fg hl))
                          (and ok-sl (= (type sl) "table") (hl-rendered-fg sl))
                          0xFFFFFF))
    (set (. opts :bg) (meta-statusline-bg))
    (set (. opts :ctermbg) (or (and ok-sl (= (type sl) "table") (. sl :ctermbg))
                               (and ok-normal (= (type normal) "table") (. normal :ctermbg))
                               0))
    (set (. opts :ctermfg) (or (and ok-hl (= (type hl) "table") (. hl :ctermfg))
                               (and ok-sl (= (type sl) "table") (. sl :ctermfg))
                               15))
    opts))

(fn statusline-fg-hl-with-bg
  [group bg-fn]
  (let [opts {:default true :reverse false :cterm {:reverse false}}
        [ok-hl hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        [ok-sl sl] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
        [ok-normal normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]]
    (set (. opts :fg) (or (and ok-hl (= (type hl) "table") (hl-rendered-fg hl))
                          (and ok-sl (= (type sl) "table") (hl-rendered-fg sl))
                          0xFFFFFF))
    (set (. opts :bg) (bg-fn))
    (set (. opts :ctermbg) (or (and ok-sl (= (type sl) "table") (. sl :ctermbg))
                               (and ok-normal (= (type normal) "table") (. normal :ctermbg))
                               0))
    (set (. opts :ctermfg) (or (and ok-hl (= (type hl) "table") (. hl :ctermfg))
                               (and ok-sl (= (type sl) "table") (. sl :ctermfg))
                               15))
    opts))

(fn statusline-sep-hl-with-bg
  [bg-fn]
  (let [opts {:default true :reverse false :cterm {:reverse false}}
        [ok-sl sl] [(pcall vim.api.nvim_get_hl 0 {:name "StatusLine" :link false})]
        [ok-normal normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]]
    (set (. opts :fg) (or (and ok-sl (= (type sl) "table") (hl-rendered-fg sl))
                          (and ok-normal (= (type normal) "table") (hl-rendered-fg normal))
                          0xFFFFFF))
    (set (. opts :bg) (bg-fn))
    (set (. opts :ctermbg) (or (and ok-sl (= (type sl) "table") (. sl :ctermbg))
                               (and ok-normal (= (type normal) "table") (. normal :ctermbg))
                               0))
    (set (. opts :ctermfg) (or (and ok-sl (= (type sl) "table") (. sl :ctermfg))
                               (and ok-normal (= (type normal) "table") (. normal :ctermfg))
                               15))
    opts))

(fn underlined-text-from
  [text-group underline-group]
  (let [opts (fg-only-hl-from text-group)
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name underline-group :link false})]]
    (set (. opts :undercurl) true)
    (when (and ok (= (type hl) "table"))
      (if (. hl :sp)
          (set (. opts :sp) (. hl :sp))
          (when (. hl :fg)
            (set (. opts :sp) (. hl :fg)))))
    opts))

(fn darken-rgb
  [n factor]
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)
            f (math.max 0 (math.min factor 1))
            dr (math.max 0 (math.min 255 (math.floor (* r (- 1 f)))))
            dg (math.max 0 (math.min 255 (math.floor (* g (- 1 f)))))
            db (math.max 0 (math.min 255 (math.floor (* b (- 1 f)))))]
        (+ (* dr 0x10000) (* dg 0x100) db))))

(fn brighten-rgb
  [n factor]
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)
            f (math.max 0 (math.min factor 1))
            br (math.max 0 (math.min 255 (math.floor (+ r (* (- 255 r) f)))))
            bg (math.max 0 (math.min 255 (math.floor (+ g (* (- 255 g) f)))))
            bb (math.max 0 (math.min 255 (math.floor (+ b (* (- 255 b) f)))))]
        (+ (* br 0x10000) (* bg 0x100) bb))))

(fn hl-bg
  [group]
  (let [[ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (hl-rendered-bg hl))))

(fn darker-bg
  [a b]
  (let [la (rgb-luma a)
        lb (rgb-luma b)]
    (if (and la lb)
        (if (<= la lb) a b)
        (or a b))))

(fn alt-bg-from
  [group]
  (let [opts {}
        base-bg (or (hl-bg group)
                    (hl-bg "Normal")
                    (hl-bg "NormalNC")
                    (hl-bg "ColorColumn")
                    (hl-bg "CursorLine")
                    0x1e1e1e)
        bg (darken-rgb base-bg 0.15)]
    (when bg
      (set (. opts :bg) bg))
    opts))

(set meta-statusline-bg
  (fn []
    (or (brighten-rgb (darker-bg (hl-bg "StatusLine")
                                 (or (hl-bg "Normal")
                                     (hl-bg "NormalNC")))
                      0.09)
        (hl-bg "StatusLine")
        (hl-bg "StatusLineNC")
        (hl-bg "Normal")
        0x2a2a2a)))

(fn meta-statusline-middle-hl
  []
  (let [opts (plain-hl-from "StatusLine")]
    (set (. opts :default) true)
    (set (. opts :bg) (meta-statusline-bg))
    opts))

(fn meta-statusline-middle-hl-with-bg
  [bg-fn]
  (let [opts (plain-hl-from "StatusLine")]
    (set (. opts :default) true)
    (set (. opts :bg) (bg-fn))
    opts))

(fn meta-preview-statusline-hl
  []
  (let [opts (plain-hl-from "StatusLine")
        base-bg (meta-preview-statusline-bg)]
    (set (. opts :default) true)
    (set (. opts :bg) base-bg)
    opts))

(set meta-preview-statusline-bg
  (fn []
    (meta-statusline-bg)))

(fn results-pulse-bg
  [step]
  (let [base (meta-statusline-bg)]
    (if (= step 2)
        (or (brighten-rgb base 0.02) base)
        (= step 3)
        (or (brighten-rgb base 0.04) base)
        (= step 4)
        (or (brighten-rgb base 0.06) base)
        (= step 5)
        (or (brighten-rgb base 0.04) base)
        (= step 6)
        (or (brighten-rgb base 0.02) base)
        (= step 7)
        (or (darken-rgb base 0.02) base)
        (= step 8)
        (or (darken-rgb base 0.04) base)
        (= step 9)
        (or (brighten-rgb base 0.06) base)
        (= step 10)
        (or (brighten-rgb base 0.04) base)
        (= step 11)
        (or (darken-rgb base 0.02) base)
        base)))

(fn cterm-bg
  [group]
  (let [[ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (. hl :ctermbg))))

(fn meta-window-cursorline-hl
  []
  (let [opts (plain-hl-from "CursorLine")
        bg (or (. opts :bg)
               (hl-bg "CursorLine")
               (hl-bg "Normal")
               0x1e1e1e)
        [ok-cl cl] [(pcall vim.api.nvim_get_hl 0 {:name "CursorLine" :link false})]
        ctermbg (or (and ok-cl (= (type cl) "table") (. cl :ctermbg))
                    (cterm-bg "Normal")
                    0)]
    (set (. opts :default) true)
    (set (. opts :bg) bg)
    (set (. opts :ctermbg) ctermbg)
    (set (. opts :underline) false)
    (set (. opts :undercurl) false)
    (set (. opts :underdotted) false)
    (set (. opts :underdashed) false)
    (set (. opts :underdouble) false)
    (set (. opts :bold) false)
    (set (. opts :italic) false)
    (set (. opts :nocombine) true)
    (set (. opts :cterm) {})
    opts))

(fn meta-window-separator-hl
  []
  (let [bg (or (hl-bg "Normal")
               (hl-bg "NormalNC")
               0x1e1e1e)
        fg (or (darken-rgb bg 0.18) bg)
        opts {:default true
              :fg fg
              :bg bg}
        ctermbg (or (cterm-bg "Normal")
                    (cterm-bg "NormalNC")
                    0)]
    (set (. opts :ctermbg) ctermbg)
    (set (. opts :ctermfg) ctermbg)
    opts))

(fn prompt-text-hl
  []
  (let [opts {:default true :bold true :cterm {:bold true}}
        [ok-normal normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]
        [ok-title title] [(pcall vim.api.nvim_get_hl 0 {:name "Title" :link false})]
        bg (and ok-normal (= (type normal) "table") (. normal :bg))
        fg0 (or (and ok-title (= (type title) "table") (. title :fg))
                (and ok-normal (= (type normal) "table") (. normal :fg)))
        dark? (and bg (< (or (rgb-luma bg) 255) 120))
        fg (if dark?
               (brighten-rgb fg0 0.18)
               fg0)]
    (when fg
      (set (. opts :fg) fg))
    opts))

(fn prompt-text-hl-from
  [group]
  (let [opts (prompt-text-hl)
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        fg (and ok (= (type hl) "table") (hl-rendered-fg hl))]
    (when fg
      (set (. opts :fg) fg))
    (when (and ok (= (type hl) "table") (. hl :ctermfg))
      (set (. opts :ctermfg) (. hl :ctermfg)))
    opts))

(fn loading-hl
  [group factor]
  (let [opts {:default true :bold true :cterm {:bold true}}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        base (and ok (= (type hl) "table") (. hl :fg))
        fg (if (and base (< factor 0))
               (darken-rgb base (math.abs factor))
               (if base
                   (brighten-rgb base factor)
                   nil))]
    (when fg
      (set (. opts :fg) fg))
    opts))

(fn apply-ui-config!
  [opts]
  (let [resolved (config.resolve opts)
        ui (. resolved :ui)]
    (set (. vim.g "meta#custom_mappings") (or (. ui :custom_mappings) {}))
    (set (. vim.g "meta#highlight_groups") (or (. ui :highlight_groups) {:All "Title" :Fuzzy "Number" :Regex "Special"}))
    (set (. vim.g "meta#syntax_on_init") (or (. ui :syntax_on_init) "buffer"))
    (set (. vim.g "meta#prefix") (or (. ui :prefix) "#"))))

(fn ensure-fennel-syntax-defaults!
  []
  (when (= (. vim.g :fennel_lua_version) nil)
    (set (. vim.g :fennel_lua_version) "5.1"))
  (when (= (. vim.g :fennel_use_luajit) nil)
    (set (. vim.g :fennel_use_luajit) (if _G.jit 1 0))))

(fn apply-statusline-highlights!
  [hi]
  (hi 0 "MetaStatuslineModeInsert" (statusline-color-from "ErrorMsg"))
  (hi 0 "MetaStatuslineModeReplace" (statusline-color-from "Todo"))
  (let [normal-mode-hl (meta-statusline-middle-hl)]
    (set (. normal-mode-hl :bold) true)
    (set (. normal-mode-hl :cterm) {:bold true})
    (hi 0 "MetaStatuslineModeNormal" normal-mode-hl))
  (hi 0 "MetaStatuslineQuery" (statusline-color-from "Normal"))
  (hi 0 "MetaStatuslineFile" (statusline-fg-hl-from "Comment"))
  (hi 0 "MetaStatuslineMiddle" (meta-statusline-middle-hl))
  (hi 0 "MetaPreviewStatusline" (meta-preview-statusline-hl))
  (hi 0 "MetaStatuslineMatcherAll" (statusline-color-from "Statement"))
  (hi 0 "MetaStatuslineMatcherFuzzy" (statusline-color-from "Number"))
  (hi 0 "MetaStatuslineMatcherRegex" (statusline-color-from "Special"))
  (hi 0 "MetaStatuslineCaseSmart" (statusline-color-from "String"))
  (hi 0 "MetaStatuslineCaseIgnore" (statusline-color-from "Special"))
  (hi 0 "MetaStatuslineCaseNormal" (statusline-color-from "Normal"))
  (hi 0 "MetaStatuslineSyntaxBuffer" (statusline-color-from "Comment"))
  (hi 0 "MetaStatuslineSyntaxMeta" (statusline-color-from "Number"))
  (hi 0 "MetaStatuslineIndicator" (statusline-color-from "Tag"))
  (hi 0 "MetaStatuslineKey" (statusline-color-from "Comment"))
  (hi 0 "MetaStatuslineFlagOn" (statusline-color-from "String"))
  (hi 0 "MetaStatuslineFlagOff" (statusline-color-from "ErrorMsg"))
  (let [bg-fn (fn [] (results-pulse-bg 1))]
    (hi 0 "MetaStatuslineMiddlePulse" (meta-statusline-middle-hl-with-bg bg-fn))
    (hi 0 "MetaStatuslineIndicatorPulse" (statusline-fg-hl-with-bg "Tag" bg-fn))
    (hi 0 "MetaStatuslineKeyPulse" (statusline-fg-hl-with-bg "Comment" bg-fn))
    (hi 0 "MetaStatuslineFlagOnPulse" (statusline-fg-hl-with-bg "String" bg-fn))
    (hi 0 "MetaStatuslineFlagOffPulse" (statusline-fg-hl-with-bg "ErrorMsg" bg-fn))))

(fn apply-search-and-prompt-highlights!
  [hi]
  (hi 0 "MetaSearchHitAll" (hit-hl "Statement" "Error"))
  (hi 0 "MetaSearchHitBuffer" (hit-hl "Statement" "Error"))
  (hi 0 "MetaSearchHitFuzzy" (hit-hl "Number" "WarningMsg"))
  (hi 0 "MetaSearchHitFuzzyBetween" (hit-hl "IncSearch" "Question"))
  (hi 0 "MetaSearchHitRegex" (hit-hl "Special" "Type"))
  (hi 0 "MetaSearchHitLgrep" (hit-hl "String" "Type"))
  (hi 0 "MetaPromptText" (prompt-text-hl))
  (each [i src (ipairs PRIMARY_LINE_GROUPS)]
    (let [suffix (tostring i)]
      (hi 0 (.. "MetaPromptText" suffix) (prompt-text-hl-from src))
      (hi 0 (.. "MetaSearchHitAll" suffix) (hit-hl-primary src "Error"))
      (hi 0 (.. "MetaSearchHitFuzzy" suffix) (hit-hl-primary src "WarningMsg"))
      (hi 0 (.. "MetaSearchHitRegex" suffix) (hit-hl-primary src "Type"))))
  (hi 0 "MetaPromptNeg" {:default true :link "ErrorMsg"})
  (hi 0 "MetaPromptAnchor" {:default true :link "SpecialChar"})
  (hi 0 "MetaPromptRegex" {:default true :link "MetaSearchHitRegex" :underline true})
  (hi 0 "MetaPromptLgrep" {:default true :link "MetaSearchHitLgrep"})
  (hi 0 "MetaPromptFileArg" {:default true :link "Directory"})
  (hi 0 "MetaPromptFlagHashOn" (statusline-color-from "String"))
  (hi 0 "MetaPromptFlagHashOff" (statusline-color-from "ErrorMsg"))
  (hi 0 "MetaPromptFlagTextOn" (fg-only-hl-from "String"))
  (hi 0 "MetaPromptFlagTextOff" (fg-only-hl-from "ErrorMsg"))
  (hi 0 "MetaPromptFlagTextFuncOn" (underlined-text-from "String" "Special"))
  (hi 0 "MetaPromptFlagTextFuncOff" (underlined-text-from "ErrorMsg" "Special")))

(fn apply-loading-and-window-highlights!
  [hi]
  (hi 0 "MetaLoading1" (loading-hl "Comment" -0.1))
  (hi 0 "MetaLoading2" (loading-hl "Comment" 0.0))
  (hi 0 "MetaLoading3" (loading-hl "Comment" 0.14))
  (hi 0 "MetaLoading4" (loading-hl "Title" 0.08))
  (hi 0 "MetaLoading5" (loading-hl "Title" 0.2))
  (hi 0 "MetaLoading6" (loading-hl "Title" 0.32))
  (hi 0 "MetaSourceLineNr" {:default true :link "LineNr"})
  (hi 0 "MetaSourceDir" {:default true :link "Directory"})
  (hi 0 "MetaSourceBoundary" (thin-underline-from "Error"))
  (hi 0 "MetaWindowCursorLine" (meta-window-cursorline-hl))
  (hi 0 "MetaWindowSeparator" (meta-window-separator-hl))
  (hi 0 "MetaSourceAltBg" (alt-bg-from "Normal")))

(fn apply-path-and-file-highlights!
  [hi]
  (each [i src (ipairs PATH_SEG_GROUPS)]
    (hi 0 (.. "MetaPathSeg" (tostring i)) {:default true :link src}))
  (hi 0 "MetaPathSep" {:default true :link "Normal"})
  (each [i src (ipairs PATH_SEG_GROUPS)]
    (hi 0 (.. "MetaPreviewStatuslinePathSeg" (tostring i))
        (statusline-fg-hl-with-bg src meta-preview-statusline-bg)))
  (hi 0 "MetaPreviewStatuslinePathSep" (statusline-sep-hl-with-bg meta-preview-statusline-bg))
  (hi 0 "MetaPreviewStatuslinePathFile" (statusline-fg-hl-with-bg "Comment" meta-preview-statusline-bg))
  (hi 0 "MetaFileSignDirty" {:default true :link "WarningMsg"})
  (hi 0 "MetaFileSignUntracked" {:default true :link "DiagnosticError"})
  (hi 0 "MetaFileSignClean" {:default true :link "LineNr"})
  (hi 0 "MetaBufSignAdded" {:default true :link "DiagnosticOk"})
  (hi 0 "MetaBufSignModified" {:default true :link "Statement"})
  (hi 0 "MetaBufSignRemoved" {:default true :link "DiagnosticError"})
  (hi 0 "MetaFileAge" {:default true :link "Comment"})
  (hi 0 "MetaFileAgeMinute" {:default true :link "DiagnosticHint"})
  (hi 0 "MetaFileAgeHour" {:default true :link "DiagnosticHint"})
  (hi 0 "MetaFileAgeDay" {:default true :link "DiagnosticInfo"})
  (hi 0 "MetaFileAgeWeek" {:default true :link "DiagnosticWarn"})
  (hi 0 "MetaFileAgeMonth" {:default true :link "Constant"})
  (hi 0 "MetaFileAgeYear" {:default true :link "DiagnosticError"})
  (each [i src (ipairs AUTHOR_GROUPS)]
    (hi 0 (.. "MetaAuthor" (tostring i)) {:default true :link src}))
  (if (= 1 (vim.fn.hlexists "NetrwPlain"))
      (hi 0 "MetaSourceFile" {:default true :link "NetrwPlain"})
      (hi 0 "MetaSourceFile" {:default true :link "Normal"})))

(fn ensure-defaults-and-highlights!
  [opts]
  (ensure-fennel-syntax-defaults!)
  (apply-ui-config! opts)
  (let [hi vim.api.nvim_set_hl]
    (apply-statusline-highlights! hi)
    (apply-search-and-prompt-highlights! hi)
    (apply-loading-and-window-highlights! hi)
    (apply-path-and-file-highlights! hi)))

(fn ensure-highlight-refresh-autocmd!
  []
  (when refresh-augroup
    (pcall vim.api.nvim_del_augroup_by_id refresh-augroup))
  (set refresh-augroup
       (vim.api.nvim_create_augroup "MetabufferHighlights" {:clear true}))
  (vim.api.nvim_create_autocmd
    ["ColorScheme" "OptionSet"]
    {:group refresh-augroup
     :pattern ["*" "background"]
     :callback (fn [event]
                 (when (or (= event.event "ColorScheme")
                           (= event.match "background"))
                   (ensure-defaults-and-highlights! last-setup-opts)
                   (pcall vim.cmd "redrawstatus")))}))

(fn ensure-command
  [name callback opts]
  (pcall vim.api.nvim_del_user_command name)
  (vim.api.nvim_create_user_command name callback opts))

(fn plugin-root
  []
  (let [src (. (debug.getinfo 1 "S") :source)
        path (if (vim.startswith src "@") (string.sub src 2) src)]
    ;; .../lua/metabuffer/init.lua -> plugin root
    (vim.fn.fnamemodify path ":p:h:h:h")))

(fn clear-module-cache
  []
  (each [k _ (pairs package.loaded)]
    (when (or (= k "metabuffer") (vim.startswith k "metabuffer."))
      (set (. package.loaded k) nil))))

(fn clear-plugin-loaded-flags!
  []
  ;; Keep compatibility with older bootstrap guards.
  (set vim.g.loaded_metabuffer nil)
  (set vim.g.meta_loaded nil))

(fn source-plugin-bootstrap!
  []
  (let [root (plugin-root)
        file (.. root "/plugin/metabuffer.lua")]
    (if (= 1 (vim.fn.filereadable file))
        (vim.cmd (.. "silent source " (vim.fn.fnameescape file)))
        (error (.. "plugin bootstrap not found: " file)))))

(fn maybe-compile!
  []
  (let [root (plugin-root)
        script (.. root "/scripts/compile-fennel.sh")]
    (if (= 1 (vim.fn.filereadable script))
        ;; Reload only needs fresh generated Lua; skip heavy maintenance work.
        (let [out (vim.fn.system ["env" "META_COMPILE_MINIMAL=1" "sh" script])]
          (if (= vim.v.shell_error 0)
              true
              (error (.. "compile failed:\n" out))))
        (error (.. "compile script not found: " script)))))

(fn M.reload
  [opts]
  "Public API: M.reload."
  (let [cfg (or opts {})
        do-compile (and cfg.compile true)]
    (when do-compile
      (maybe-compile!))
    (clear-module-cache)
    (clear-plugin-loaded-flags!)
    (source-plugin-bootstrap!)
    (vim.notify (if do-compile "[metabuffer] reloaded (compiled)" "[metabuffer] reloaded") vim.log.levels.INFO)
    true))

(fn M.setup
  [opts]
  "Public API: M.setup."
  (events.load-providers! (vim.list_extend (vim.deepcopy compat-providers) [core-events-provider]))
  (set last-setup-opts opts)
  (router.configure opts)
  (ensure-defaults-and-highlights! opts)
  (ensure-highlight-refresh-autocmd! )
  (ensure-command "Meta"
    (fn [args] (router.entry_start args.args args.bang))
    {:nargs "?" :bang true})

  (ensure-command "MetaResume"
    (fn [args] (router.entry_resume args.args))
    {:nargs "?"})

  (ensure-command "MetaCursorWord"
    (fn [] (router.entry_cursor_word false))
    {:nargs 0})

  (ensure-command "MetaResumeCursorWord"
    (fn [] (router.entry_cursor_word true))
    {:nargs 0})

  (ensure-command "MetaSync"
    (fn [args] (router.entry_sync args.args))
    {:nargs "?"})

  (ensure-command "MetaPush"
    (fn [] (router.entry_push))
    {:nargs 0})

  (ensure-command "MetaReload"
    (fn [args]
      (let [[ok err] [(pcall M.reload {:compile args.bang})]]
        (when-not ok
          (vim.notify (.. "[metabuffer] reload failed: " (tostring err)) vim.log.levels.ERROR))))
    {:nargs 0 :bang true})

  true)

(fn M.update-results-loading-pulse!
  [step]
  "Refresh the shared results statusline pulse highlights for one animation step."
  (let [hi vim.api.nvim_set_hl
        bg-fn (fn [] (results-pulse-bg step))]
    (hi 0 "MetaStatuslineMiddlePulse" (meta-statusline-middle-hl-with-bg bg-fn))
    (hi 0 "MetaStatuslineIndicatorPulse" (statusline-fg-hl-with-bg "Tag" bg-fn))
    (hi 0 "MetaStatuslineKeyPulse" (statusline-fg-hl-with-bg "Comment" bg-fn))
    (hi 0 "MetaStatuslineFlagOnPulse" (statusline-fg-hl-with-bg "String" bg-fn))
    (hi 0 "MetaStatuslineFlagOffPulse" (statusline-fg-hl-with-bg "ErrorMsg" bg-fn))))

(set M.defaults (. config :defaults))

M
