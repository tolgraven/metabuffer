Run a pass applying these rules:
- Relevant info in AGENTS.md (clojure style etc)
- Small docstrings unless function truly minimal and immediately obvious.
- Line up `let` inputs, map values etc.
- Argument list on separate line unless oneline function (then keep everything on one line).
- Avoid using `set` unless necessary (such as when interacting with nvim api etc)
- Ensure files aren't overly long (router.fnl is over 1900 lines as of this writing). Refactor as needed to get sub-600 or at the very least sub-1000 line files.
- Avoid massive `(if x (do ...)` blocks, break apart such functions instead.
  - Especially avoid `(if x y nil)` and `(if x nil y)`, use `(when)`
  - Don't use nested `if` clauses if Fennel's `cond` equivalent for `if` can be used.
- Ensure defaults and configs are kept separate from main code.
- Unless performance critical, prefer `symbol'` (new declaration with updated data) over repeat `set` on a symbol.
- use `{:keys [a b c]}`-style destructuring in general rather than multi-line set's or explicit mirroring.
  In fennel this is: `(let [{: a : b : c &as all} opts] ...)`
- Prefer passing through specs, opts, maps in general (possibly after dissocing irrelevant keys) rather than making explicit locals all the time.
- Overwhelmingly prefer `let` over `local`.
- Use `cljlib` (repo submodule dep) whenever possible, to stay close to equivalent Clojure.
- Try to keep functions under 40 lines always, though there can be exceptions (if there are big internal closing functions, especially). But the exceptions should be very few and have good reason.
- Always max 120 cols width. Prefer below 100 when possible. Try to align right hand side in let or map with rhs on lines above if it has to wrap to next line.
- Prefer passing maps over having > 6 args to a fn. Group maps so makes sense. `spec` is a good map name, `opts`, or for inner fns `m` can also work for general cases.
