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
;;;   :on-session-ready!     {:session ...}
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
;;;
;;; Source / query events
;;;   :on-source-switch!     {:session ... :old-source str :new-source str}
;;;   :on-query-update!      {:session ... :query str}
;;;   :on-selection-change!  {:session ... :line-nr N}
;;;
;;; Project events
;;;   :on-project-bootstrap! {:session ...}
;;;   :on-project-complete!  {:session ...}
;;;
;;; Action events
;;;   :on-accept!            {:session ...}
;;;   :on-cancel!            {:session ...}
;;;   :on-restore-ui!        {:session ...}
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
(var profile? false)

(fn M.set-profile!
  [enabled]
  "Enable or disable per-handler timing logs (via debug.log)."
  (set profile? (not (not enabled))))

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
  [spec event-key args]
  "Invoke spec.handler with pcall.  When profiling is active, measure
   wall-clock time and log domain/source/event/priority/elapsed-µs."
  (if profile?
      (let [t0 (vim.uv.hrtime)
            (ok err) (pcall spec.handler args)
            elapsed-us (/ (- (vim.uv.hrtime) t0) 1000)]
        (debug.log :event-bus
                   (string.format "%s  %s/%s  p=%d  %.1fµs%s"
                                  event-key
                                  (or spec.domain "?")
                                  (or spec.source "?")
                                  spec.priority elapsed-us
                                  (if ok "" (.. "  ERR: " (tostring err))))))
      (pcall spec.handler args)))

(fn M.send
  [event-key args]
  "Fire all handlers registered for event-key in priority order.
   args is a plain table; each handler receives it directly.
   Handlers failing their role-filter are skipped silently.
   All invocations are pcall-isolated."
  (let [list (. handlers-by-event event-key)
        args* (or args {})]
    (when list
      (each [_ spec (ipairs list)]
        (when (matches-filter? spec args*)
          (pcall-handler! spec event-key args*))))))

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

M
