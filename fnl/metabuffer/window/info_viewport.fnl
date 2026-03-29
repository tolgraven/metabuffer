(local M {})
(local helper-mod (require :metabuffer.window.info_helpers))

(local info-placeholder-line (. helper-mod :info-placeholder-line))
(local info-range (. helper-mod :info-range))
(local numeric-max (. helper-mod :numeric-max))
(local info-winbar-active? (. helper-mod :info-winbar-active?))

(fn M.new
  [opts]
  "Build info-window viewport and sizing helpers."
  (let [{: info-min-width : info-max-width : info-height
         : resize-info-window! : valid-info-win? : session-host-win
         : project-loading-pending?} (or opts {})]
    (fn set-info-topline!
      [session top]
      (when (valid-info-win? session)
        (vim.api.nvim_win_call
          session.info-win
          (fn []
            (let [line-count (math.max 1 (vim.api.nvim_buf_line_count session.info-buf))
                  top* (math.max 1 (math.min top line-count))
                  selected1 (math.max top* (math.min (+ session.meta.selected_index 1) line-count))
                  view (vim.fn.winsaveview)]
              (set (. view :topline) top*)
              (set (. view :lnum) selected1)
              (set (. view :col) 0)
              (set (. view :leftcol) 0)
              (pcall vim.fn.winrestview view))))))

    (fn ensure-buffer-shape!
      [session render-stop]
      (when (and session.info-buf
                 (vim.api.nvim_buf_is_valid session.info-buf))
        (let [needed (math.max 1 (or render-stop 0))
              current (vim.api.nvim_buf_line_count session.info-buf)]
          (when (~= current needed)
            (let [bo (. vim.bo session.info-buf)]
              (set (. bo :modifiable) true))
            (if (< current needed)
                (vim.api.nvim_buf_set_lines
                  session.info-buf
                  current
                  current
                  false
                  (vim.tbl_map
                    (fn [_] (info-placeholder-line session))
                    (vim.fn.range (+ current 1) needed)))
                (vim.api.nvim_buf_set_lines session.info-buf needed -1 false []))
            (let [bo (. vim.bo session.info-buf)]
              (set (. bo :modifiable) false))))))

    (fn fit-info-width!
      [session lines]
      (when (valid-info-win? session)
        (let [widths (vim.tbl_map (fn [line] (vim.fn.strdisplaywidth (or line ""))) (or lines []))
              max-len (numeric-max widths 0)
              host-win (session-host-win session)
              host-width (if (and session.window-local-layout
                                  host-win
                                  (vim.api.nvim_win_is_valid host-win))
                             (vim.api.nvim_win_get_width host-win)
                             vim.o.columns)
              max-available (math.max info-min-width (math.floor (* host-width 0.34)))
              upper (math.min info-max-width max-available)
              fit-target (math.max info-min-width (math.min max-len upper))
              frozen-width (and (not session.project-mode) session.info-fixed-width)
              target (or frozen-width fit-target)
              height (info-height session)]
          (when (and (not session.project-mode)
                     (not frozen-width))
            (set session.info-fixed-width (math.max info-min-width fit-target)))
          (resize-info-window! session target height))))

    (fn info-max-width-now
      [session]
      (let [host-win (session-host-win session)
            host-width (if (and session
                                session.window-local-layout
                                host-win
                                (vim.api.nvim_win_is_valid host-win))
                           (vim.api.nvim_win_get_width host-win)
                           vim.o.columns)
            max-available (math.max info-min-width (math.floor (* host-width 0.34)))]
        (math.min info-max-width max-available)))

    (fn info-visible-range
      [session meta total cap]
      (if (or (<= total 0) (<= cap 0))
          [1 0]
          (if (and session
                   meta
                   meta.win
                   (vim.api.nvim_win_is_valid meta.win.window))
              (let [view (vim.api.nvim_win_call meta.win.window (fn [] (vim.fn.winsaveview)))
                    top0 (math.max 1 (math.min total (or (. view :topline) 1)))
                    overlay-offset (if (info-winbar-active? session project-loading-pending?) 1 0)
                    top (math.max 1 (math.min total (+ top0 overlay-offset)))
                    height0 (math.max 1 (vim.api.nvim_win_get_height meta.win.window))
                    height (math.max 1 (- height0 overlay-offset))
                    stop0 (math.min total (+ top height -1))
                    shown (math.max 1 (+ (- stop0 top) 1))]
                (if (<= shown cap)
                    [top stop0]
                    [top (+ top cap -1)]))
              (info-range meta.selected_index total cap))))

    {:ensure-buffer-shape! ensure-buffer-shape!
     :fit-info-width! fit-info-width!
     :info-max-width-now info-max-width-now
     :info-visible-range info-visible-range
     :set-info-topline! set-info-topline!}))

M
