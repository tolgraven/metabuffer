(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local router (require :metabuffer.router))

(local M {})

(fn rgb-luma
  [n]
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)]
        (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b)))))

(fn statusline-color-from
  [group]
  (let [opts {:reverse false :cterm {:reverse false}}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]
        [nok normal] [(pcall vim.api.nvim_get_hl 0 {:name "Normal" :link false})]]
    (when (and ok (= (type hl) "table"))
      (var fg (. hl :fg))
      (var cfg (. hl :ctermfg))
      (when (and (not fg) (. hl :reverse))
        (set fg (. hl :bg)))
      (when (and (not cfg) (or (. hl :reverse) (and (. hl :cterm) (. (. hl :cterm) :reverse))))
        (set cfg (. hl :ctermbg)))
      (if fg
          (set (. opts :bg) fg)
          (when (and nok (= (type normal) "table") (. normal :bg))
            (set (. opts :bg) (. normal :bg))))
      (if cfg
          (set (. opts :ctermbg) cfg)
          (when (and nok (= (type normal) "table") (. normal :ctermbg))
            (set (. opts :ctermbg) (. normal :ctermbg))))
      (when (. hl :bold)
        (set (. opts :bold) (. hl :bold))))
    (let [bl (rgb-luma (. opts :bg))]
      (if (and bl (> bl 128))
          (set (. opts :fg) 0x000000)
          (set (. opts :fg) 0xFFFFFF)))
    (if (and (. opts :ctermbg) (> (. opts :ctermbg) 7))
        (set (. opts :ctermfg) 0)
        (set (. opts :ctermfg) 15))
    opts))

(fn undercurl-from
  [group]
  (let [opts {:default true :undercurl true}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (when (. hl :sp)
        (set (. opts :sp) (. hl :sp)))
      (when (and (not (. opts :sp)) (. hl :fg))
        (set (. opts :sp) (. hl :fg))))
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
      (when (. hl :fg)
        (set (. opts :fg) (. hl :fg)))
      (when (. hl :bg)
        (set (. opts :bg) (. hl :bg)))
      (when (. hl :ctermfg)
        (set (. opts :ctermfg) (. hl :ctermfg)))
      (when (. hl :ctermbg)
        (set (. opts :ctermbg) (. hl :ctermbg))))
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

(fn hl-bg
  [group]
  (let [[ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (. hl :bg))))

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

(fn ensure-defaults-and-highlights!
  []
  (set (. vim.g "meta#custom_mappings") (or (. vim.g "meta#custom_mappings") {}))
  (set (. vim.g "meta#highlight_groups") (or (. vim.g "meta#highlight_groups") {:All "Title" :Fuzzy "Number" :Regex "Special"}))
  (set (. vim.g "meta#syntax_on_init") (or (. vim.g "meta#syntax_on_init") "buffer"))
  (set (. vim.g "meta#prefix") (or (. vim.g "meta#prefix") "#"))
  (local hi vim.api.nvim_set_hl)
  (hi 0 "MetaStatuslineModeInsert" (statusline-color-from "Tag"))
  (hi 0 "MetaStatuslineModeReplace" (statusline-color-from "Todo"))
  (hi 0 "MetaStatuslineModeNormal" (statusline-color-from "Comment"))
  (hi 0 "MetaStatuslineQuery" (statusline-color-from "Normal"))
  (hi 0 "MetaStatuslineFile" (statusline-color-from "Comment"))
  ;; Fill area around %= should blend with the host statusline theme.
  (hi 0 "MetaStatuslineMiddle" (plain-hl-from "StatusLine"))
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
  (hi 0 "MetaSearchHitAll" (hit-hl "Statement" "Error"))
  (hi 0 "MetaSearchHitBuffer" (hit-hl "Statement" "Error"))
  (hi 0 "MetaSearchHitFuzzy" (hit-hl "Number" "WarningMsg"))
  (hi 0 "MetaSearchHitFuzzyBetween" (hit-hl "IncSearch" "Question"))
  (hi 0 "MetaSearchHitRegex" (hit-hl "Special" "Type"))
  (hi 0 "MetaSourceLineNr" {:default true :link "LineNr"})
  (hi 0 "MetaSourceDir" {:default true :link "Directory"})
  (hi 0 "MetaSourceBoundary" (thin-underline-from "Error"))
  ;; Intentionally not :default so theme/background recalculations always apply.
  (hi 0 "MetaSourceAltBg" (alt-bg-from "Normal"))
  ;; Prefer netrw-like plain file coloring if present.
  (if (= 1 (vim.fn.hlexists "NetrwPlain"))
      (hi 0 "MetaSourceFile" {:default true :link "NetrwPlain"})
      (hi 0 "MetaSourceFile" {:default true :link "Normal"})))

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
        (let [out (vim.fn.system ["sh" script])]
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
  []
  "Public API: M.setup."
  (ensure-defaults-and-highlights!)
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
        (when (not ok)
          (vim.notify (.. "[metabuffer] reload failed: " (tostring err)) vim.log.levels.ERROR))))
    {:nargs 0 :bang true})

  true)

M
