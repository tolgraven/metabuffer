;;; Event Bus — generic lifecycle dispatcher for metabuffer.
;;;
;;; Modules register interest in events by declaring an :events map.
;;; The bus collects handlers, sorts by :priority, and fires them in order.
;;; Every handler receives a single args map; failed handlers are pcall-isolated.
;;;
;;; ── Registration ──────────────────────────────────────────────────────
;;;
;;;   (events.register! module)
;;;
;;;   module = {:name   "my-module"      ;; shown in profiling logs
;;;             :domain "compat"         ;; logical grouping, shown in profiling logs
;;;             :events {:<event-key> <spec>}}
;;;
;;;   <spec> is one of:
;;;     - a bare handler fn              → {: handler :priority 50}
;;;     - a config map                   → {:handler fn :priority N :role-filter kw-or-list}
;;;     - a sequential list of maps      → multiple handlers for one event
;;;
;;; ── Dispatch ──────────────────────────────────────────────────────────
;;;
;;;   (events.send :on-buf-create! {:buf 42 :role :prompt})
;;;
;;;   All handlers registered for the event key are called in priority order.
;;;   Each handler receives the full args map and may destructure what it needs.
;;;
;;; ── Role filtering ────────────────────────────────────────────────────
;;;
;;;   :role-filter on a spec restricts the handler to specific :role values
;;;   in the args map.  Supply a single keyword or a list of keywords.
;;;   Omit or nil to match all.
;;;
;;; ── Handler spec keys ─────────────────────────────────────────────────
;;;   :handler      fn    (required) Receives the full args map.
;;;   :priority     int   (optional) Lower = runs first.  Default 50.
;;;   :role-filter  kw or [kw]  (optional) Restrict by args.role.
;;;
;;; ── Event Catalog ─────────────────────────────────────────────────────
;;;
;;; Plugin lifecycle
;;;   :on-plugin-init!       {:config ...}
;;;   :on-plugin-teardown!   {}
;;;
;;; Session lifecycle
;;;   :on-session-start!     {:session ...}
;;;   :on-session-ready!     {:session ... :refresh-lines bool
;;;                           :restore-view? bool
;;;                           :refresh-signs? bool :capture-sign-baseline? bool}
;;;   :on-session-stop!      {:session ...}
;;;
;;; Buffer lifecycle
;;;   :on-buf-create!        {:buf N  :role kw}
;;;   :on-buf-teardown!      {:buf N  :role kw}
;;;     buf roles: :meta :prompt :preview :info :history-browser :context
;;;
;;; Window lifecycle
;;;   :on-win-create!        {:win N  :role kw}
;;;   :on-win-teardown!      {:win N  :role kw}
;;;     win roles: :main :prompt :preview :info :origin
;;;
;;; Mode events
;;;   :on-insert-enter!      {:session ...}
;;;   :on-mode-switch!       {:session ... :kind str :old str :new str}
;;;   :on-prompt-focus!      {:session ...}
;;;   :on-loading-state!     {:session ...}
;;;
;;; Source / query events
;;;   :on-source-switch!     {:session ... :old-source str :new-source str}
;;;   :on-source-pool-change! {:session ... :refresh-lines bool
;;;                            :phase kw-or-nil :force? bool
;;;                            :restore-view? bool :phase-only? bool}
;;;   :on-source-syntax-refresh! {:session ... :immediate? bool}
;;;   :on-query-update!      {:session ... :query str :refresh-lines bool
;;;                           :refresh-signs? bool :capture-sign-baseline? bool}
;;;   :on-selection-change!  {:session ... :line-nr N :refresh-lines bool
;;;                           :force-refresh? bool}
;;;
;;; Project events
;;;   :on-project-bootstrap! {:session ... :refresh-lines bool
;;;                           :restore-view? bool}
;;;   :on-project-complete!  {:session ... :refresh-lines bool
;;;                           :restore-view? bool}
;;;
;;; Action events
;;;   :on-accept!            {:session ...}
;;;   :on-cancel!            {:session ...}
;;;   :on-restore-ui!        {:session ... :restore-view? bool}
;;;   :on-restore-view!      {:session ...}
;;;
;;; Directive events
;;;   :on-directive!         {:session ...  :key str  :value any
;;;                           :change {:old any :new any
;;;                                    :activated? bool :deactivated? bool
;;;                                    :kind str :provider-type str}}

(local M {})
(local debug (require :metabuffer.debug))

(local default-priority 50)
(local handlers-by-event {})
(local profile-stats {})
(var profile? false)
(var posted-queue [])
(local posted-by-key {})
(var posted-scheduled? false)

(fn cpu-us
  []
  (let [uv (or vim.uv vim.loop)
        usage (and uv uv.getrusage (uv.getrusage))]
    (if usage
        (+ (* (. (. usage :utime) :sec) 1000000)
           (. (. usage :utime) :usec)
           (* (. (. usage :stime) :sec) 1000000)
           (. (. usage :stime) :usec))
        0)))

(fn hrtime
  []
  (vim.uv.hrtime))

(fn M.set-profile!
  [enabled]
  "Enable or disable per-handler timing logs (via debug.log)."
  (set profile? (not (not enabled))))

(fn clear-profile-stats!
  []
  (each [k _ (pairs profile-stats)]
    (set (. profile-stats k) nil)))

(fn event-stats-for
  [event-key]
  (let [event-stats (or (. profile-stats event-key) {})]
    (when (= (. profile-stats event-key) nil)
      (set (. profile-stats event-key) event-stats))
    (when (= (. event-stats :emissions) nil)
      (set (. event-stats :emissions) []))
    event-stats))

(fn handler-key
  [spec]
  (.. (or spec.domain "?") "/" (or spec.source "?")))

(fn post-key
  [event-key opts]
  (or (. opts :dedupe-key) event-key))

(fn loggable-summary
  [event-key args meta]
  (let [summary {:event event-key
                 :mode (or (and meta (. meta :mode)) :sync)}]
    (when (and meta (. meta :post-key))
      (set (. summary :post-key) (. meta :post-key)))
    (when (~= (. args :phase) nil)
      (set (. summary :phase) (. args :phase)))
    (when (~= (. args :force?) nil)
      (set (. summary :force?) (. args :force?)))
    (when (~= (. args :restore-view?) nil)
      (set (. summary :restore-view?) (. args :restore-view?)))
    (when (~= (. args :refresh-lines) nil)
      (set (. summary :refresh-lines) (. args :refresh-lines)))
    (when (~= (. args :line-nr) nil)
      (set (. summary :line-nr) (. args :line-nr)))
    (when (~= (. args :query) nil)
      (let [q (tostring (. args :query))]
        (set (. summary :query)
             (if (> (# q) 48)
                 (.. (string.sub q 1 48) "…")
                 q))))
    summary))

(fn log-event!
  [scope event-key args meta]
  (debug.log scope (vim.inspect (loggable-summary event-key (or args {}) meta))))

(fn handler-stats-for
  [event-stats key]
  (let [handler-stats (or (. event-stats key) {})]
    (when (= (. event-stats key) nil)
      (set (. event-stats key) handler-stats))
    handler-stats))

(fn start-emission!
  [event-key meta]
  (let [event-stats (event-stats-for event-key)
        emissions (. event-stats :emissions)
        emission {:index (+ (# emissions) 1)
                  :event event-key
                  :mode (or (and meta (. meta :mode)) :sync)
                  :elapsed_us 0
                  :cpu_us 0
                  :handler_count 0
                  :handlers []}]
    (when meta
      (when (. meta :queue_delay_us)
        (set emission.queue_delay_us (. meta :queue_delay_us)))
      (when (. meta :post-key)
        (set emission.post_key (. meta :post-key)))
      (when (. meta :flush_index)
        (set emission.flush_index (. meta :flush_index))))
    (table.insert emissions emission)
    (set event-stats.count (+ 1 (or event-stats.count 0)))
    [event-stats emission]))

(fn record-post!
  [event-key opts status]
  (let [event-stats (event-stats-for event-key)
        key (tostring (post-key event-key opts))
        field (if (= status :suppressed) :suppressed_count :posted_count)]
    (set (. event-stats field) (+ 1 (or (. event-stats field) 0)))
    (when (= status :suppressed)
      (set (. event-stats :last_suppressed_key) key))
    event-stats))

(fn accumulate-profile!
  [event-stats emission spec elapsed-us cpu-elapsed-us ok err]
  (set event-stats.handler_count (+ 1 (or event-stats.handler_count 0)))
  (set event-stats.elapsed_us (+ elapsed-us (or event-stats.elapsed_us 0)))
  (set event-stats.cpu_us (+ cpu-elapsed-us (or event-stats.cpu_us 0)))
  (set emission.handler_count (+ 1 (or emission.handler_count 0)))
  (set emission.elapsed_us (+ elapsed-us (or emission.elapsed_us 0)))
  (set emission.cpu_us (+ cpu-elapsed-us (or emission.cpu_us 0)))
  (let [handler-key0 (handler-key spec)
        handler-stats (handler-stats-for event-stats handler-key0)
        handler-run {:domain (or spec.domain "?")
                     :source (or spec.source "?")
                     :priority (or spec.priority default-priority)
                     :elapsed_us elapsed-us
                     :cpu_us cpu-elapsed-us
                     :ok ok}]
    (set handler-stats.count (+ 1 (or handler-stats.count 0)))
    (set handler-stats.elapsed_us (+ elapsed-us (or handler-stats.elapsed_us 0)))
    (set handler-stats.cpu_us (+ cpu-elapsed-us (or handler-stats.cpu_us 0)))
    (when (not ok)
      (set handler-stats.last_error (tostring err))
      (set handler-run.error (tostring err)))
    (table.insert (. emission :handlers) handler-run)))

(fn normalize-spec
  [spec]
  "Normalise a bare fn or partial config map into a full spec table."
  (if (= (type spec) :function)
      {:handler spec :priority default-priority}
      (let [out (vim.deepcopy spec)]
        (when (not out.priority)
          (set out.priority default-priority))
        out)))

(fn register-module!
  [mod]
  "Index a module's :events declarations into the handlers-by-event map.
   Stamps :source (from :name) and :domain onto each resolved spec."
  (let [events (or (. mod :events) {})
        mod-name (or (. mod :name) "?")
        mod-domain (or (. mod :domain) "?")]
    (each [_ list (pairs handlers-by-event)]
      (var i (# list))
      (while (> i 0)
        (let [spec (. list i)]
          (when (and (= (or spec.source "?") mod-name)
                     (= (or spec.domain "?") mod-domain))
            (table.remove list i)))
        (set i (- i 1))))
    (each [event-key raw (pairs events)]
      (let [specs (if (and (= (type raw) :table) (. raw 1)) raw [raw])]
        (each [_ raw-spec (ipairs specs)]
          (let [spec (normalize-spec raw-spec)]
            (when (= (type spec.handler) :function)
              (when (not spec.source) (set spec.source mod-name))
              (when (not spec.domain) (set spec.domain mod-domain))
              (when (not (. handlers-by-event event-key))
                (set (. handlers-by-event event-key) []))
              (table.insert (. handlers-by-event event-key) spec))))))))

(fn sort-handlers!
  []
  "Sort every event's handler list by ascending priority (lower = first)."
  (each [_ list (pairs handlers-by-event)]
    (table.sort list (fn [a b] (< a.priority b.priority)))))

(fn matches-filter?
  [spec args]
  "Return true when spec passes all filter criteria against the args map.
   :role-filter kw-or-list — args.role must be in the list."
  (if (and spec.role-filter (not (= spec.role-filter nil)))
      (let [filter spec.role-filter
            role args.role
            roles (if (= (type filter) :table) filter [filter])
            hit false]
        (var found hit)
        (each [_ r (ipairs roles) &until found]
          (when (= r role) (set found true)))
        found)
      true))

(fn pcall-handler!
  [spec event-key args event-stats emission]
  "Invoke spec.handler with pcall.  When profiling is active, measure
   wall-clock time and log domain/source/event/priority/elapsed-µs."
  (if profile?
      (let [t0 (vim.uv.hrtime)
            cpu0 (cpu-us)
            (ok err) (pcall spec.handler args)
            elapsed-us (/ (- (vim.uv.hrtime) t0) 1000)
            cpu-elapsed-us (math.max 0 (- (cpu-us) cpu0))]
        (accumulate-profile! event-stats emission spec elapsed-us cpu-elapsed-us ok err)
        (debug.log :event-bus
                   (string.format "%s  %s/%s  p=%d  wall=%.1fµs cpu=%.1fµs%s"
                                  event-key
                                  (or spec.domain "?")
                                  (or spec.source "?")
                                  spec.priority elapsed-us cpu-elapsed-us
                                  (if ok "" (.. "  ERR: " (tostring err))))))
      (pcall spec.handler args)))

(fn send-now!
  [event-key args meta]
  (let [list (. handlers-by-event event-key)
        args* (or args {})
        [event-stats emission] (if (and profile? list)
                                   (start-emission! event-key meta)
                                   [nil nil])]
    (when list
      (each [_ spec (ipairs list)]
        (when (matches-filter? spec args*)
          (pcall-handler! spec event-key args* event-stats emission))))))

(fn flush-posted-queue!
  []
  (when (> (# posted-queue) 0)
    (let [pending posted-queue]
      (set posted-queue [])
      (each [k _ (pairs posted-by-key)]
        (set (. posted-by-key k) nil))
      (var flush-index 0)
      (each [_ item (ipairs pending)]
        (set flush-index (+ flush-index 1))
        (let [queue-delay-us (/ (- (hrtime) item.posted_at) 1000)
              event-stats (record-post! item.event-key item.opts :posted)]
          (set (. event-stats :flushed_count) (+ 1 (or (. event-stats :flushed_count) 0)))
          (send-now! item.event-key item.args {:mode :posted
                                               :queue_delay_us queue-delay-us
                                               :post-key (tostring item.post-key)
                                               :flush_index flush-index}))))))

(fn schedule-posted-flush!
  []
  (when (not posted-scheduled?)
    (set posted-scheduled? true)
    (vim.schedule
      (fn []
        (set posted-scheduled? false)
        (flush-posted-queue!)))))

(fn M.send
  [event-key args]
  "Fire all handlers registered for event-key in priority order.
   args is a plain table; each handler receives it directly.
   Handlers failing their role-filter are skipped silently.
   All invocations are pcall-isolated."
  (log-event! "events.send" event-key (or args {}) {:mode :sync})
  (send-now! event-key args {:mode :sync}))

(fn M.post
  [event-key args opts]
  "Queue event-key for next scheduler tick. When :supersede? is true,
   a pending event with the same :dedupe-key is replaced instead of queued twice."
  (let [opts* (or opts {})
        post-key0 (post-key event-key opts*)
        pending (. posted-by-key post-key0)]
    (when (and pending (. opts* :supersede?))
      (record-post! (. pending :event-key) (. pending :opts) :suppressed)
      (set (. pending :event-key) event-key)
      (set (. pending :args) (or args {}))
      (set (. pending :opts) opts*)
      (set (. pending :post-key) post-key0)
      (set (. pending :posted_at) (hrtime)))
    (when (not (and pending (. opts* :supersede?)))
      (let [item {:event-key event-key
                  :args (or args {})
                  :opts opts*
                  :post-key post-key0
                  :posted_at (hrtime)}]
        (table.insert posted-queue item)
        (set (. posted-by-key post-key0) item)))
    (log-event! "events.post" event-key (or args {}) {:mode :posted
                                                      :post-key post-key0})
    (schedule-posted-flush!)))

(fn M.register!
  [mod]
  "Register a module's :events declarations at runtime.
   Re-sorts all handler lists after insertion."
  (register-module! mod)
  (sort-handlers!))

(fn M.load-providers!
  [providers]
  "Register a list of provider modules into the event bus.
   Registers all modules first, then sorts once — more efficient than
   calling register! N times."
  (each [_ mod (ipairs (or providers []))]
    (register-module! mod))
  (sort-handlers!))

(fn M.registered-events
  []
  "Return a sorted list of event keys that have at least one handler."
  (let [names []]
    (each [k _ (pairs handlers-by-event)]
      (table.insert names k))
    (table.sort names)
    names))

(fn M.handlers-for
  [event-key]
  "Return the sorted handler list for event-key, or nil."
  (. handlers-by-event event-key))

(fn M.profile-stats
  []
  "Return a deep copy of accumulated profile stats keyed by event name."
  (vim.deepcopy profile-stats))

(fn M.reset-profile-stats!
  []
  "Clear accumulated event profile stats."
  (clear-profile-stats!))

(fn M.flush-posted!
  []
  "Run and clear the currently queued posted events immediately."
  (set posted-scheduled? false)
  (each [_ item (ipairs (or posted-queue []))]
    (log-event! "events.flush"
                (. item :event-key)
                (or (. item :args) {})
                {:mode :posted
                 :post-key (. item :post-key)}))
  (flush-posted-queue!))

M
