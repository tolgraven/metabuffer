(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local session-builders-mod (require :metabuffer.router.session_builders))
(local session-query-mod (require :metabuffer.router.session_query))
(local M {})

(fn M.new
  [opts]
  "Build session state and start-query resolution helpers."
  (let [{: history-api : history-store : query-mod : router-util-mod
         : session-view : prompt-window-mod} (or opts {})]
    (let [session-query (session-query-mod.new
                          {:history-api history-api
                           :query-mod query-mod})
          resolve-start-query-state (. session-query :resolve-start-query-state)
          session-builders (session-builders-mod.new
                             {:history-store history-store
                              :query-mod query-mod
                              :router-util-mod router-util-mod
                              :prompt-window-mod prompt-window-mod})
          prompt-animates? (. session-builders :prompt-animates?)
          build-prompt-window (. session-builders :build-prompt-window)
          build-session-state (. session-builders :build-session-state)]

    (fn restored-hidden-session
      [router-state maybe-restore-hidden-ui! source-buf existing project-mode]
      (when (and existing
                 existing.ui-hidden
                 maybe-restore-hidden-ui!
                 existing.meta
                 existing.meta.buf
                 (= (clj.boolean existing.project-mode) (clj.boolean project-mode))
                 (= source-buf existing.meta.buf.buffer))
        (router-util-mod.clear-file-caches! router-state existing)
        (maybe-restore-hidden-ui! existing true)
        existing.meta))

    (fn build-session-condition
      [query mode source-view project-mode]
      (let [condition (session-view.setup-state query mode source-view)]
        (set condition.selected-index
             (if (and project-mode (= mode "start"))
                 (math.max 0 (- (or (. source-view :lnum)
                                    (+ (or (. condition :selected-index) 0) 1))
                                1))
                 (or (. condition :selected-index) 0)))
        condition))

    {:resolve-start-query-state resolve-start-query-state
     :prompt-animates? prompt-animates?
     :restored-hidden-session restored-hidden-session
     :build-session-condition build-session-condition
     :build-prompt-window build-prompt-window
     :build-session-state build-session-state})))

M
