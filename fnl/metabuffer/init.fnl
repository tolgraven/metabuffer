(local router (require :metabuffer.router))

(local M {})

(fn rgb-luma [n]
  (if (not n)
      nil
      (let [r (math.floor (/ n 0x10000))
            g (math.floor (% (/ n 0x100) 0x100))
            b (% n 0x100)]
        (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b)))))

(fn statusline-color-from [group]
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

(fn undercurl-from [group]
  (let [opts {:default true :undercurl true}
        [ok hl] [(pcall vim.api.nvim_get_hl 0 {:name group :link false})]]
    (when (and ok (= (type hl) "table"))
      (when (. hl :fg)
        (set (. opts :fg) (. hl :fg)))
      (when (. hl :bg)
        (set (. opts :bg) (. hl :bg)))
      (when (. hl :sp)
        (set (. opts :sp) (. hl :sp)))
      (when (and (not (. opts :sp)) (. opts :fg))
        (set (. opts :sp) (. opts :fg))))
    opts))

(fn plain-hl-from [group]
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

(fn ensure-defaults-and-highlights! []
  (set (. vim.g "meta#custom_mappings") (or (. vim.g "meta#custom_mappings") {}))
  (set (. vim.g "meta#highlight_groups") (or (. vim.g "meta#highlight_groups") {:All "Title" :Fuzzy "Number" :Regex "Special"}))
  (set (. vim.g "meta#syntax_on_init") (or (. vim.g "meta#syntax_on_init") "buffer"))
  (set (. vim.g "meta#prefix") (or (. vim.g "meta#prefix") "#"))
  (local hi vim.api.nvim_set_hl)
  (hi 0 "MetaStatuslineModeInsert" (statusline-color-from "Tag"))
  (hi 0 "MetaStatuslineModeReplace" (statusline-color-from "Todo"))
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
  (hi 0 "MetaStatuslineSyntaxBuffer" (statusline-color-from "Normal"))
  (hi 0 "MetaStatuslineSyntaxMeta" (statusline-color-from "Number"))
  (hi 0 "MetaStatuslineIndicator" (statusline-color-from "Tag"))
  (hi 0 "MetaStatuslineKey" (statusline-color-from "Comment"))
  (hi 0 "MetaSearchHitAll" (undercurl-from "Statement"))
  (hi 0 "MetaSearchHitBuffer" (undercurl-from "Statement"))
  (hi 0 "MetaSearchHitFuzzy" (undercurl-from "Number"))
  (hi 0 "MetaSearchHitFuzzyBetween" (undercurl-from "IncSearch"))
  (hi 0 "MetaSearchHitRegex" (undercurl-from "Special")))

(fn ensure-command [name callback opts]
  (pcall vim.api.nvim_del_user_command name)
  (vim.api.nvim_create_user_command name callback opts))

(fn plugin-root []
  (let [src (. (debug.getinfo 1 "S") :source)
        path (if (vim.startswith src "@") (string.sub src 2) src)]
    ;; .../lua/metabuffer/init.lua -> plugin root
    (vim.fn.fnamemodify path ":p:h:h:h")))

(fn clear-module-cache []
  (each [k _ (pairs package.loaded)]
    (when (or (= k "metabuffer") (vim.startswith k "metabuffer."))
      (set (. package.loaded k) nil))))

(fn clear-plugin-loaded-flags! []
  ;; Keep compatibility with older bootstrap guards.
  (set vim.g.loaded_metabuffer nil)
  (set vim.g.meta_loaded nil))

(fn source-plugin-bootstrap! []
  (let [root (plugin-root)
        file (.. root "/plugin/metabuffer.lua")]
    (if (= 1 (vim.fn.filereadable file))
        (vim.cmd (.. "silent source " (vim.fn.fnameescape file)))
        (error (.. "plugin bootstrap not found: " file)))))

(fn maybe-compile! []
  (let [root (plugin-root)
        script (.. root "/scripts/compile-fennel.sh")]
    (if (= 1 (vim.fn.filereadable script))
        (let [out (vim.fn.system ["sh" script])]
          (if (= vim.v.shell_error 0)
              true
              (error (.. "compile failed:\n" out))))
        (error (.. "compile script not found: " script)))))

(fn M.reload [opts]
  (let [cfg (or opts {})
        do-compile (and cfg.compile true)]
    (when do-compile
      (maybe-compile!))
    (clear-module-cache)
    (clear-plugin-loaded-flags!)
    (source-plugin-bootstrap!)
    (vim.notify (if do-compile "[metabuffer] reloaded (compiled)" "[metabuffer] reloaded") vim.log.levels.INFO)
    true))

(fn M.setup []
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
