(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Build info float window lifecycle helpers."
  (let [{: floating-window-mod : info-min-width : info-height
         : animation-mod : animate-enter? : info-fade-ms
         : valid-info-win? : session-host-win : effective-info-height
         : info-winbar-active? : project-loading-pending?
         : events : apply-metabuffer-window-highlights!
         : info-buffer-mod} opts]
    (fn info-config-signature
      [cfg]
      (table.concat
        [(or (. cfg :relative) "")
         (tostring (or (. cfg :win) 0))
         (or (. cfg :anchor) "")
         (tostring (or (. cfg :row) 0))
         (tostring (or (. cfg :col) 0))
         (tostring (or (. cfg :width) 0))
         (tostring (or (. cfg :height) 0))
         (tostring (not (not (. cfg :focusable))))]
        "|"))

    (fn apply-info-config-if-changed!
      [session cfg]
      (when (valid-info-win? session)
        (let [sig (info-config-signature cfg)]
          (when (~= sig session.info-config-sig)
            (set session.info-config-sig sig)
            (pcall vim.api.nvim_win_set_config session.info-win cfg)))))

    (fn info-window-config
      [session width height]
      (let [host-win (or (session-host-win session) (vim.api.nvim_get_current_win))
            _own-winbar-row (if (info-winbar-active? session project-loading-pending?) 1 0)]
        (if session.window-local-layout
            (let [[wb-ok wb-val] [(pcall vim.api.nvim_get_option_value "winbar" {:win host-win})]
                  has-winbar? (and wb-ok
                                   (= (type wb-val) "string")
                                   (~= wb-val ""))
                  base-row (if has-winbar? 1 0)
                  row base-row
                  host-height (vim.api.nvim_win_get_height host-win)
                  wanted-h (math.max 1 height)
                  max-h (math.max 1 (- host-height (math.max row 0)))
                  h (math.min wanted-h max-h)]
              {:relative "win"
               :win host-win
               :anchor "NW"
               :row row
               :col (vim.api.nvim_win_get_width host-win)
               :width width
               :height h
               :focusable false})
            {:relative "editor"
             :anchor "NE"
             :row 1
             :col vim.o.columns
             :width width
             :height (math.max 1 height)
             :focusable false})))

    (fn info-target-config
      [session]
      (let [width info-min-width
            height (effective-info-height session info-height project-loading-pending?)]
        {:width width
         :height height
         :target (info-window-config session width height)}))

    (fn animate-info-enter?
      [session prompt-target]
      (and animation-mod
           animate-enter?
           (animate-enter? session)
           (animation-mod.enabled? session :info)
           (not session.info-animated?)
           prompt-target))

    (fn initial-info-config
      [target animate-info?]
      (if animate-info?
          (let [start (vim.deepcopy target)]
            (set (. start :col) (+ (. target :col) 8))
            (set (. start :winblend) 100)
            start)
          target))

    (fn configure-info-buffer!
      [session buf]
      (info-buffer-mod.new buf)
      (set session.info-buf buf)
      buf)

    (fn configure-info-window!
      [session target win]
      (set session.info-win win.window)
      (set session.info-config-sig (info-config-signature target))
      (events.send :on-win-create! {:win session.info-win :role :info})
      (apply-metabuffer-window-highlights! session.info-win)
      (let [wo (. vim.wo win.window)]
        (set (. wo :statusline) "")
        (set (. wo :winbar) "")
        (set (. wo :number) false)
        (set (. wo :relativenumber) false)
        (set (. wo :wrap) false)
        (set (. wo :linebreak) false)
        (set (. wo :signcolumn) "no")
        (set (. wo :foldcolumn) "0")
        (set (. wo :spell) false)
        (set (. wo :cursorline) false)))

    (fn start-info-enter-animation!
      [session update! cfg target]
      (set session.info-animated? true)
      (set session.info-render-suspended? true)
      (set session.info-post-fade-refresh? true)
      (pcall vim.api.nvim_set_option_value "winblend" 100 {:win session.info-win})
      (vim.defer_fn
        (fn []
          (when (valid-info-win? session)
            (animation-mod.animate-float!
              session
              "info-enter"
              session.info-win
              cfg
              target
              100
              (or vim.g.meta_float_winblend 13)
              (animation-mod.duration-ms session :info (or info-fade-ms 220))
              {:kind :info
               :done! (fn [_]
                        (when (valid-info-win? session)
                          (set session.info-post-fade-refresh? nil)
                          (set session.info-render-suspended? false)
                          (update! session true)))})))
        17))

    (fn ensure-window!
      [session update!]
      (when-not (valid-info-win? session)
        (let [{: target} (info-target-config session)
              buf (vim.api.nvim_create_buf false true)
              animate-info? (animate-info-enter? session target)
              cfg (initial-info-config target animate-info?)
              win (floating-window-mod.new vim buf cfg)]
          (configure-info-buffer! session buf)
          (configure-info-window! session target win)
          (when animate-info?
            (start-info-enter-animation! session update! cfg target)))))

    (fn settle-window!
      [session]
      (when (valid-info-win? session)
        (let [width (vim.api.nvim_win_get_width session.info-win)
              height (effective-info-height session info-height project-loading-pending?)
              cfg (info-window-config session width height)]
          (apply-info-config-if-changed! session cfg))))

    (fn resize-window!
      [session width height]
      (when (valid-info-win? session)
        (let [cfg (info-window-config session width height)]
          (apply-info-config-if-changed! session cfg))))

    (fn refresh-statusline!
      [session]
      "Re-apply float-local statusline options after focus/plugin redraw churn."
      (when (valid-info-win? session)
        (let [total (# (or (and session session.meta session.meta.buf session.meta.buf.indices) []))
              start-index (or session.info-start-index 1)
              stop-index (or session.info-stop-index (if (> total 0) total 0))
              range (if (<= total 0)
                        "0/0"
                        (.. start-index "-" stop-index "/" total))
              loading-title (if (project-loading-pending? session)
                                (let [streamed (math.max 0 (- (or session.lazy-stream-next 1) 1))
                                      total-files (or session.lazy-stream-total 0)]
                                  (if (> total-files 0)
                                      (.. "Info  loading " streamed "/" total-files " files")
                                      "Info  loading project"))
                                (if session.info-highlight-fill-pending?
                                    (.. "Info  loading " range)
                                    nil))
              winbar (if loading-title
                         (.. "%#Comment#" loading-title)
                         "")]
          (pcall vim.api.nvim_set_option_value "statusline" "" {:win session.info-win})
          (pcall vim.api.nvim_set_option_value "winbar" winbar {:win session.info-win}))))

    (fn close-window!
      [session]
      (when (valid-info-win? session)
        (pcall vim.api.nvim_win_close session.info-win true))
      (set session.info-win nil)
      (set session.info-buf nil)
      (set session.info-config-sig nil)
      (set session.info-post-fade-refresh? nil)
      (set session.info-render-suspended? nil)
      (set session.info-highlight-fill-pending? nil)
      (set session.info-highlight-fill-token nil)
      (set session.info-line-meta-refresh-pending nil)
      (set session.info-fixed-width nil))

    {:ensure-window! ensure-window!
     :settle-window! settle-window!
     :resize-window! resize-window!
     :refresh-statusline! refresh-statusline!
     :close-window! close-window!}))

M
