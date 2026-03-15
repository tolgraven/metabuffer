# USING CLJLIB MORE

We use Cljlib for some stuff, but not much. We want a full rewrite where we use things like `defn`, `def`, (instead of `fn` and `local` or `var`), all the `clojure.string` niceness, `str` and `sub` in general, general clojure approaches to solving problems.
As much purity as possible, build complete maps rather than separately setting values on a datastructure, generally use `symbol'` for updated data rather than modifying in place (unless necessary for Neovim purposes).
- Use all of the Clojure core library available to us.
- Don't forget core.async (should be very useful) and some other stuff is also available.
- Generally stick to Clojure best practices, including keeping functions small and isolating side-effecting sections.

Update your instructions to always follow this way of coding in the future.
