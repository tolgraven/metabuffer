Run a pass applying these rules:
- Relevant info in AGENTS.md (clojure style etc)
- Small docstrings unless function truly minimal and immediately obvious.
- Argument list on separate line unless oneline function (then keep everything on one line).
- Avoid using `set` unless necessary (such as when interacting with nvim api etc)
- Ensure files aren't overly long (router.fnl is over 1900 lines as of this writing). Refactor as needed to get sub-600 or at the very least sub-1000 line files.
- Avoid massive `(if x (do ...)` blocks, break apart such functions instead.
- Ensure defaults and configs are kept separate from main code.
