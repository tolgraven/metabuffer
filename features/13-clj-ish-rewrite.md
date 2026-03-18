# USING CLJLIB MORE

We currently use Cljlib (`:io.gitlab.andreyorst.cljlib.core` main entry point) for some stuff, but not much. We want a full rewrite where we use things like `defn`, `def`, (instead of `fn` and `local` or `var`), all the `clojure.string` niceness, `str` and `sub` in general, general Clojure approaches to solving problems.
As much purity as possible, build complete maps rather than separately setting values on a datastructure, generally use `symbol'` for updated data rather than modifying in place (unless necessary for Neovim purposes).
- Use all of the Clojure core library available to us.
  - Always use `require-macros` to import all macros unqualified, and use them as such.
  - Use `import` to import all core functions unqualified, and use them as such.
- Completely avoid all usages of core.async, since it requires Lua 5.2+, which Neovim does not have.
- Generally stick to Clojure best practices, including keeping functions small and isolating side-effecting sections.

Update your instructions to always follow this way of coding in the future.
