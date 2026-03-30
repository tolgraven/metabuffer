(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local file-info (require :metabuffer.source.file_info))
(local helper-mod (require :metabuffer.window.info_helpers))
(local info-row-mod (require :metabuffer.window.info_row))
(local info-viewport-mod (require :metabuffer.window.info_viewport))

(local info-content-ns (vim.api.nvim_create_namespace "MetaInfoWindow"))
(local info-selection-ns (vim.api.nvim_create_namespace "MetaInfoSelection"))
(local str (. helper-mod :str))
(local join-str (. helper-mod :join-str))
(local indices-slice-sig (. helper-mod :indices-slice-sig))
(local ref-path (. helper-mod :ref-path))
(local refs-slice-sig (. helper-mod :refs-slice-sig))

(fn M.new
  [opts]
  "Build info window render/update helpers."
  (let [info-min-width (. opts :info-min-width)
        info-max-width (. opts :info-max-width)
        info-max-lines (. opts :info-max-lines)
        info-height (. opts :info-height)
        debug-log (. opts :debug-log)
        read-file-lines-cached (. opts :read-file-lines-cached)
        read-file-view-cached (. opts :read-file-view-cached)
        resize-info-window! (. opts :resize-info-window!)
        refresh-info-statusline! (. opts :refresh-info-statusline!)
        valid-info-win? (. opts :valid-info-win?)
        session-host-win (. opts :session-host-win)
        ext-start-in-file (. opts :ext-start-in-file)
        icon-field (. opts :icon-field)
        project-loading-pending? (. opts :project-loading-pending?)]
    (fn sync-info-selection!
      [session meta]
      (when (and (valid-info-win? session)
                 session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [info-lines (vim.api.nvim_buf_line_count session.info-buf)
              selected1 (+ meta.selected_index 1)
              row0 (if (and (> info-lines 0)
                            (> selected1 0))
                       (math.max 0 (math.min (- selected1 1) (- info-lines 1)))
                       nil)]
          (vim.api.nvim_buf_clear_namespace session.info-buf info-selection-ns 0 -1)
          (when (and row0 (>= row0 0) (< row0 info-lines))
            (vim.api.nvim_buf_add_highlight session.info-buf info-selection-ns "Visual" row0 0 -1)))))

    (let [row-builder (info-row-mod.new
                        {:info-content-ns info-content-ns
                         :info-height info-height
                         :refresh-info-statusline! refresh-info-statusline!
                         :read-file-lines-cached read-file-lines-cached
                         :read-file-view-cached read-file-view-cached
                         :ext-start-in-file ext-start-in-file
                         :icon-field icon-field})
          apply-info-highlights! (. row-builder :apply-highlights!)
          build-info-lines (. row-builder :build-info-lines)
          schedule-info-highlight-fill! (. row-builder :schedule-highlight-fill!)]

    (let [viewport (info-viewport-mod.new
                     {:info-min-width info-min-width
                      :info-max-width info-max-width
                      :info-max-lines info-max-lines
                      :info-height info-height
                      :resize-info-window! resize-info-window!
                      :valid-info-win? valid-info-win?
                      :session-host-win session-host-win
                      :project-loading-pending? project-loading-pending?})
          set-info-topline! (. viewport :set-info-topline!)
          ensure-regular-info-buffer-shape! (. viewport :ensure-buffer-shape!)
          fit-info-width! (. viewport :fit-info-width!)
          info-max-width-now (. viewport :info-max-width-now)
          info-visible-range (. viewport :info-visible-range)]

    (fn render-info-lines!
      [{: session : meta : render-start : render-stop : visible-start : visible-stop}]
      (let [refs (or meta.buf.source-refs [])
            idxs (or meta.buf.indices [])
            _ (set session.info-start-index visible-start)
            _ (set session.info-stop-index visible-stop)
            _ (set session.info-render-start render-start)
            _ (set session.info-render-stop render-stop)
            built (build-info-lines
                    {:session session
                     :refs refs
                     :idxs idxs
                     :target-width (info-max-width-now session)
                     :start-index render-start
                     :stop-index render-stop
                     :visible-start visible-start
                     :visible-stop visible-stop})
            raw-lines (. built :lines)
            lines (if (= (type raw-lines) "table")
                      (vim.tbl_map str raw-lines)
                      [(str raw-lines)])
            highlights (or (. built :highlights) [])
            deferred-rows (or (. built :deferred-rows) [])
            lnum-digit-width (or (. built :lnum-digit-width) 1)]
        (debug-log (join-str " " ["info render"
                                  (.. "hits=" (# idxs))
                                  (.. "lines=" (# lines))]))
        (set session.info-highlight-fill-token (+ 1 (or session.info-highlight-fill-token 0)))
        (set session.info-highlight-fill-pending? false)
        (fit-info-width! session lines)
        (ensure-regular-info-buffer-shape! session render-stop)
        (let [bo (. vim.bo session.info-buf)]
          (set (. bo :modifiable) true))
        (let [[ok-set err-set] [(pcall vim.api.nvim_buf_set_lines session.info-buf (- render-start 1) render-stop false lines)]]
          (when-not ok-set
            (debug-log (.. "info set_lines failed: " (tostring err-set)))))
        (vim.api.nvim_buf_clear_namespace session.info-buf info-content-ns (- render-start 1) render-stop)
        (apply-info-highlights! session info-content-ns highlights)
        (schedule-info-highlight-fill!
          {:session session
           :refs refs
           :target-width (info-max-width-now session)
           :lnum-digit-width lnum-digit-width
           :deferred-rows deferred-rows})
        (let [bo (. vim.bo session.info-buf)]
          (set (. bo :modifiable) false))
        (set-info-topline! session visible-start)
        (refresh-info-statusline! session)))

    (fn render-current-range!
      [session meta]
      (let [total (# (or meta.buf.indices []))
            [start-index stop-index] (info-visible-range session meta total info-max-lines)
            overscan (math.max 1 (info-height session))
            render-start (math.max 1 (- start-index overscan))
            render-stop (math.min total (+ stop-index overscan))]
        (render-info-lines!
          {:session session
           :meta meta
           :render-start render-start
           :render-stop render-stop
           :visible-start start-index
           :visible-stop stop-index})
        (sync-info-selection! session meta)
        [start-index stop-index]))

    (fn schedule-regular-line-meta-refresh!
      [session meta start-index stop-index]
      (let [refs (or meta.buf.source-refs [])
            idxs (or meta.buf.indices [])
            first-row (and (> (# idxs) 0) (. idxs start-index))
            first-ref (and first-row (. refs first-row))
            path (ref-path session first-ref)]
        (var rerender! nil)
        (set rerender!
             (fn []
               (when (and session
                          session.info-buf
                          (vim.api.nvim_buf_is_valid session.info-buf)
                          (not session.project-mode)
                          session.single-file-info-ready)
                 (if (or session.scroll-animating?
                         session.scroll-command-view
                         session.scroll-sync-pending
                         session.selection-refresh-pending)
                     (when-not session.info-line-meta-refresh-pending
                       (set session.info-line-meta-refresh-pending true)
                       (vim.defer_fn
                         (fn []
                           (set session.info-line-meta-refresh-pending false)
                           (rerender!))
                         90))
                     (let [[start1 stop1] (render-current-range! session meta)]
                       (set session.info-start-index start1)
                       (set session.info-stop-index stop1))))))
        (when (and session.single-file-info-fetch-ready
                   (~= path "")
                   (= 1 (vim.fn.filereadable path)))
          (let [lnums []]
            (for [i start-index stop-index]
              (let [src-idx (. idxs i)
                    ref (. refs src-idx)]
                (when (and ref
                           (= (ref-path session ref) path)
                           (= (type ref.lnum) "number"))
                  (table.insert lnums ref.lnum))))
            (table.sort lnums)
            (when (> (# lnums) 0)
              (let [first-lnum (. lnums 1)
                    last-lnum (. lnums (# lnums))
                    range-key (.. path ":" start-index ":" stop-index ":" first-lnum ":" last-lnum)]
                (when (~= range-key session.info-line-meta-range-key)
                  (set session.info-line-meta-range-key range-key)
                  ((. file-info :ensure-file-status-async!)
                    session
                    path
                    (fn []
                      (when (= range-key session.info-line-meta-range-key)
                        (rerender!))))
                  ((. file-info :ensure-line-meta-range-async!)
                    session
                    path
                    lnums
                    (fn []
                      (when (= range-key session.info-line-meta-range-key)
                        (rerender!)))))))))))

    (fn update-regular!
      [session refresh-lines]
      (when (and session.info-render-suspended?
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (set session.info-post-fade-refresh? nil)
        (set session.info-render-suspended? false))
      (when (and (not session.info-render-suspended?)
                 session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [meta session.meta
              _ (refresh-info-statusline! session)
              force-refresh? (or (= session.info-render-sig nil)
                                 (= session.info-start-index nil)
                                 (= session.info-stop-index nil))
              selected1 (+ meta.selected_index 1)
              idxs (or meta.buf.indices [])
              overscan (math.max 1 (info-height session))
              [wanted-start wanted-stop] (info-visible-range session meta (# idxs) info-max-lines)
              render-start (if (> (# idxs) 0) (math.max 1 (- wanted-start overscan)) 1)
              render-stop (if (> (# idxs) 0) (math.min (# idxs) (+ wanted-stop overscan)) 0)
              start-index (or session.info-start-index 1)
              stop-index (or session.info-stop-index 0)
              rendered-start (or session.info-render-start 1)
              rendered-stop (or session.info-render-stop 0)
              out-of-range (or (< selected1 start-index) (> selected1 stop-index))
              range-changed (or (~= wanted-start start-index)
                                (~= wanted-stop stop-index))
              rendered-range-changed (or (< wanted-start rendered-start)
                                        (> wanted-stop rendered-stop)
                                        (~= render-start rendered-start)
                                        (~= render-stop rendered-stop))
              sig (join-str
                    "|"
                    [(# idxs)
                     (indices-slice-sig idxs render-start render-stop)
                     (refs-slice-sig session meta.buf.source-refs idxs render-start render-stop)
                     render-start
                     render-stop
                     (or session.active-source-key "")
                     (or session.info-file-entry-view "")
                     (info-max-width-now session)
                     (info-height session)
                     vim.o.columns
                     (str (clj.boolean session.single-file-info-ready))
                     (str (clj.boolean session.single-file-info-fetch-ready))])]
          (if (or force-refresh?
                  refresh-lines
                  out-of-range
                  range-changed
                  rendered-range-changed
                  (~= session.info-render-sig sig))
              (do
                (when refresh-lines
                  (set session.info-line-meta-range-key nil))
                (set session.info-render-sig sig)
                (render-info-lines!
                  {:session session
                   :meta meta
                   :render-start render-start
                   :render-stop render-stop
                   :visible-start wanted-start
                   :visible-stop wanted-stop})
                (set session.info-start-index wanted-start)
                (set session.info-stop-index wanted-stop)
                (sync-info-selection! session meta)
                (schedule-regular-line-meta-refresh! session meta wanted-start wanted-stop))
              (do
                (set-info-topline! session wanted-start)
                (sync-info-selection! session meta))))))

      {:fit-info-width! fit-info-width!
       :info-visible-range info-visible-range
       :render-info-lines! render-info-lines!
       :sync-info-selection! sync-info-selection!
       :update-regular! update-regular!}))))

M
