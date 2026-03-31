(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local info-buffer-mod (require :metabuffer.buffer.info))
(local helper-mod (require :metabuffer.window.info_helpers))
(local base-window-mod (require :metabuffer.window.base))
(local events (require :metabuffer.events))
(local info-float-mod (require :metabuffer.window.info_float))
(local info-project-mod (require :metabuffer.project.info_view))
(local info-render-mod (require :metabuffer.window.info_render))
(local apply-metabuffer-window-highlights! (. base-window-mod :apply-metabuffer-window-highlights!))

(local loading-skeleton-lines (. helper-mod :loading-skeleton-lines))
(local valid-info-win? (. helper-mod :valid-info-win?))
(local session-host-win (. helper-mod :session-host-win))
(local ext-start-in-file (. helper-mod :ext-start-in-file))
(local icon-field (. helper-mod :icon-field))
(local refs-slice-sig (. helper-mod :refs-slice-sig))
(local info-winbar-active? (. helper-mod :info-winbar-active?))
(local effective-info-height (. helper-mod :effective-info-height))

(fn startup-layout-pending?
  [session]
  (let [initializing (or session.startup-initializing false)
        animating (or session.prompt-animating? false)]
    (and session session.project-mode (or initializing animating))))

(fn build-info-float
  [deps project-loading-pending?]
  (info-float-mod.new
    {:floating-window-mod (. deps :floating-window-mod)
     :info-min-width (. deps :info-min-width)
     :info-height (. deps :info-height)
     :animation-mod (. deps :animation-mod)
     :animate-enter? (. deps :animate-enter?)
     :info-fade-ms (. deps :info-fade-ms)
     :valid-info-win? valid-info-win?
     :session-host-win session-host-win
     :effective-info-height effective-info-height
     :info-winbar-active? info-winbar-active?
     :project-loading-pending? project-loading-pending?
     :events events
     :apply-metabuffer-window-highlights! apply-metabuffer-window-highlights!
     :info-buffer-mod info-buffer-mod}))

(fn build-info-render
  [deps resize-info-window! refresh-info-statusline! project-loading-pending?]
  ((. info-render-mod :new)
    {:info-min-width (. deps :info-min-width)
     :info-max-width (. deps :info-max-width)
     :info-max-lines (. deps :info-max-lines)
     :info-height (. deps :info-height)
     :debug-log (. deps :debug-log)
     :read-file-lines-cached (. deps :read-file-lines-cached)
     :read-file-view-cached (. deps :read-file-view-cached)
     :resize-info-window! resize-info-window!
     :refresh-info-statusline! refresh-info-statusline!
     :valid-info-win? valid-info-win?
     :session-host-win session-host-win
     :ext-start-in-file ext-start-in-file
     :icon-field icon-field
     :project-loading-pending? project-loading-pending?}))

(fn build-project-info
  [deps ensure-info-window settle-info-window! refresh-info-statusline!
   render-info-lines! sync-info-selection! info-visible-range
   fit-info-width! set-info-topline!]
  (info-project-mod.new
    {:startup-layout-pending? startup-layout-pending?
     :loading-skeleton-lines loading-skeleton-lines
     :info-height (. deps :info-height)
     :ensure-info-window ensure-info-window
     :settle-info-window! settle-info-window!
     :refresh-info-statusline! refresh-info-statusline!
     :render-info-lines! render-info-lines!
     :sync-info-selection! sync-info-selection!
     :refs-slice-sig refs-slice-sig
     :info-visible-range info-visible-range
     :fit-info-width! fit-info-width!
     :set-info-topline! set-info-topline!
     :info-max-lines (. deps :info-max-lines)
     :debug-log (. deps :debug-log)
     :valid-info-win? valid-info-win?}))

(fn update-info!
  [session refresh-lines ensure-info-window settle-info-window!
   update-project! update-regular!]
  (ensure-info-window session)
  (settle-info-window! session)
  (let [refresh-lines (if (= refresh-lines nil) true refresh-lines)]
    (if session.project-mode
        (update-project! session refresh-lines)
        (update-regular! session refresh-lines))))

(fn M.new
  [opts]
  "Create right-side info window renderer and synchronizer."
  (let [deps (or opts {})]
    (var update! nil)
    (var project-loading-pending? nil)
    (var update-project! nil)
    (fn project-loading?
      [session]
      (project-loading-pending? session))
    (let [info-float (build-info-float deps project-loading?)
          ensure-info-window (fn [session]
                               ((. info-float :ensure-window!) session update!))
          settle-info-window! (. info-float :settle-window!)
          resize-info-window! (. info-float :resize-window!)
          refresh-info-statusline! (. info-float :refresh-statusline!)
          close-info-window! (. info-float :close-window!)
          info-render (build-info-render deps resize-info-window! refresh-info-statusline! project-loading?)
          update-regular! (. info-render :update-regular!)
          fit-info-width! (. info-render :fit-info-width!)
          render-info-lines! (. info-render :render-info-lines!)
          set-info-topline! (. info-render :set-info-topline!)
          sync-info-selection! (. info-render :sync-info-selection!)
          info-visible-range (. info-render :info-visible-range)
          project-info (build-project-info
                         deps
                         ensure-info-window
                         settle-info-window!
                         refresh-info-statusline!
                         render-info-lines!
                         sync-info-selection!
                         info-visible-range
                         fit-info-width!
                         set-info-topline!)]
      (set project-loading-pending? (. project-info :project-loading-pending?))
      (set update-project! (. project-info :update-project!))
      (set update!
           (fn [session refresh-lines]
             (update-info!
               session
               refresh-lines
               ensure-info-window
               settle-info-window!
               update-project!
               update-regular!)))
      {:close-window! close-info-window!
       :update! update!
       :refresh-statusline! refresh-info-statusline!})))

M
