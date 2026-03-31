(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local helper-mod (require :metabuffer.window.info_helpers))
(local info-row-mod (require :metabuffer.window.info_row))
(local info-regular-mod (require :metabuffer.window.info_regular))
(local info-viewport-mod (require :metabuffer.window.info_viewport))

(local info-content-ns (vim.api.nvim_create_namespace "MetaInfoWindow"))
(local info-selection-ns (vim.api.nvim_create_namespace "MetaInfoSelection"))
(local str (. helper-mod :str))
(local join-str (. helper-mod :join-str))

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

    (let [regular-info (info-regular-mod.new
                         {:info-height info-height
                          :info-max-lines info-max-lines
                          :refresh-info-statusline! refresh-info-statusline!
                          :render-info-lines! render-info-lines!
                          :set-info-topline! set-info-topline!
                          :sync-info-selection! sync-info-selection!
                          :info-visible-range info-visible-range
                          :info-max-width-now info-max-width-now})]

      {:fit-info-width! fit-info-width!
       :info-visible-range info-visible-range
       :render-info-lines! render-info-lines!
       :set-info-topline! set-info-topline!
       :sync-info-selection! sync-info-selection!
       :update-regular! (. regular-info :update-regular!)})))))

M
