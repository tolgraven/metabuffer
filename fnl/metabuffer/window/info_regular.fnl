(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local file-info (require :metabuffer.source.file_info))
(local helper-mod (require :metabuffer.window.info_helpers))

(local join-str (. helper-mod :join-str))
(local indices-slice-sig (. helper-mod :indices-slice-sig))
(local ref-path (. helper-mod :ref-path))
(local refs-slice-sig (. helper-mod :refs-slice-sig))

(fn M.new
  [opts]
  "Build regular-mode info window update helpers."
  (let [{: info-height : info-max-lines
         : refresh-info-statusline! : render-info-lines! : set-info-topline!
         : sync-info-selection! : info-visible-range : info-max-width-now}
        (or opts {})]
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
                     (tostring (not (not session.single-file-info-ready)))
                     (tostring (not (not session.single-file-info-fetch-ready)))])]
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

    {:update-regular! update-regular!}))

M
