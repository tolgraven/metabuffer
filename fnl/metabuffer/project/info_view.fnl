(import-macros {: when-let : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Build project-mode info window update helpers."
  (let [{: startup-layout-pending? : loading-skeleton-lines : info-height
         : ensure-info-window : settle-info-window! : refresh-info-statusline!
         : render-info-lines! : sync-info-selection! : refs-slice-sig
         : info-range : info-max-lines : debug-log : valid-info-win?
         } opts]
    (fn project-loading-pending?
      [session]
      (let [startup (startup-layout-pending? session)
            bootstrap-pending (or session.project-bootstrap-pending false)
            bootstrapped (or session.project-bootstrapped false)
            stream-done (or session.lazy-stream-done false)
            pending (and session
                         session.project-mode
                         (or startup
                             bootstrap-pending
                             (not bootstrapped)
                             (not stream-done)))]
        pending))

    (fn render-project-loading!
      [session fit-info-width!]
      (let [lines (loading-skeleton-lines (info-height session))
            ns (vim.api.nvim_create_namespace "MetaInfoWindow")]
        (set session.info-start-index 1)
        (set session.info-stop-index (# lines))
        (let [bo (. vim.bo session.info-buf)]
          (set bo.modifiable true))
        (set session.info-highlight-fill-token (+ 1 (or session.info-highlight-fill-token 0)))
        (set session.info-highlight-fill-pending? false)
        (set session.info-showing-project-loading? true)
        (set session.info-render-sig nil)
        (fit-info-width! session lines)
        (vim.api.nvim_buf_set_lines session.info-buf 0 -1 false lines)
        (vim.api.nvim_buf_clear_namespace session.info-buf ns 0 -1)
        (for [row 0 (- (# lines) 1)]
          (vim.api.nvim_buf_add_highlight session.info-buf ns "Comment" row 0 -1))
        (let [bo (. vim.bo session.info-buf)]
          (set bo.modifiable false))))

    (fn update-project-startup!
      [session fit-info-width! info-visible-range]
      (set session.info-project-loading-active? true)
      (ensure-info-window session)
      (when (and session.info-render-suspended?
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (set session.info-post-fade-refresh? nil)
        (set session.info-render-suspended? false))
      (settle-info-window! session)
      (when (and (not session.info-render-suspended?)
                 session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [meta session.meta
              idxs (or meta.buf.indices [])
              total (# idxs)]
          (if (> total 0)
              (let [[wanted-start wanted-stop] (info-visible-range
                                                 session
                                                 meta
                                                 total
                                                 info-max-lines)]
                (set session.info-showing-project-loading? false)
                (render-info-lines!
                  session
                  meta
                  wanted-start
                  wanted-stop
                  wanted-start
                  wanted-stop)
                (sync-info-selection! session meta))
              (render-project-loading! session fit-info-width!)))))

    (fn settle-info-render-state!
      [session]
      (ensure-info-window session)
      (when (and session.info-render-suspended?
                 (not session.prompt-animating?)
                 (not session.startup-initializing))
        (set session.info-post-fade-refresh? nil)
        (set session.info-render-suspended? false))
      (settle-info-window! session))

    (fn project-info-debug!
      [session refresh-lines]
      (when debug-log
        (debug-log
          (table.concat
            ["info project"
             (if refresh-lines " refresh" "")
             (if session.project-bootstrap-pending " bootstrap-pending" "")
             (if session.info-project-loading-active? " loading-active" "")
             (if session.info-render-suspended? " suspended" "")]
            ""))))

    (fn project-info-force-refresh?
      [session refresh-lines]
      (or refresh-lines
          (= session.info-render-sig nil)
          session.info-project-loading-active?
          session.info-showing-project-loading?))

    (fn project-info-range-state
      [session meta]
      (let [idxs (or meta.buf.indices [])
            total (# idxs)
            [wanted-start wanted-stop] (info-range meta.selected_index total info-max-lines)
            out-of-range (or (< (or session.info-start-index 1) wanted-start)
                             (> (or session.info-stop-index 0) wanted-stop))
            range-changed (or (~= wanted-start (or session.info-start-index 1))
                              (~= wanted-stop (or session.info-stop-index 0)))]
        {:wanted-start wanted-start
         :wanted-stop wanted-stop
         :out-of-range out-of-range
         :range-changed range-changed}))

    (fn project-info-render-sig
      [session meta wanted-start wanted-stop]
      (let [idxs (or meta.buf.indices [])
            refs (or meta.buf.source-refs [])]
        (table.concat
          [(or session.info-max-width 0)
           wanted-start
           wanted-stop
           (refs-slice-sig session refs idxs wanted-start wanted-stop)
           (or session.info-project-loading-active? false)]
          "|")))

    (fn schedule-project-info-finish-refresh!
      [session]
      (when-not session.info-project-finish-refresh-pending?
        (set session.info-project-finish-refresh-pending? true)
        (vim.defer_fn
          (fn []
            (set session.info-project-finish-refresh-pending? false)
            (when (and (valid-info-win? session)
                       (not (project-loading-pending? session)))
              (set session.info-project-loading-active? false)
              (set session.info-showing-project-loading? false)
              (refresh-info-statusline! session)))
          30)))

    (fn rerender-project-info!
      [session meta wanted-start wanted-stop loading-finished?]
      (set session.info-render-sig (project-info-render-sig session meta wanted-start wanted-stop))
      (set session.info-project-loading-active? (not loading-finished?))
      (set session.info-showing-project-loading? false)
      (render-info-lines!
        session
        meta
        wanted-start
        wanted-stop
        wanted-start
        wanted-stop)
      (sync-info-selection! session meta)
      (when loading-finished?
        (schedule-project-info-finish-refresh! session)))

    (fn update-project!
      [session refresh-lines fit-info-width! info-visible-range]
      (if (project-loading-pending? session)
          (update-project-startup! session fit-info-width! info-visible-range)
          (do
            (settle-info-render-state! session)
            (project-info-debug! session refresh-lines)
            (refresh-info-statusline! session)
            (when (and (not session.info-render-suspended?)
                       session.info-buf
                       (vim.api.nvim_buf_is_valid session.info-buf))
              (let [meta session.meta
                    loading-finished? (not (not session.info-project-loading-active?))
                    force-refresh? (project-info-force-refresh? session refresh-lines)
                    {: wanted-start : wanted-stop : out-of-range : range-changed}
                    (project-info-range-state session meta)]
                (when (or force-refresh? out-of-range range-changed)
                  (let [sig (project-info-render-sig session meta wanted-start wanted-stop)]
                    (when (or force-refresh?
                              out-of-range
                              range-changed
                              (~= session.info-render-sig sig))
                      (rerender-project-info!
                        session
                        meta
                        wanted-start
                        wanted-stop
                        loading-finished?))))
                (sync-info-selection! session meta))))))

    {:project-loading-pending? project-loading-pending?
     :update-project! update-project!}))

M
