# Unit tests

Functionality is getting brittle, and there are often regressions. So we need a comprehensive unit testing setup that agents can easily run to ensure this doesn't happen.

Since we're writing a Neovim plugin we'll use `plenary.nvim` unit testing harness.
We'll need a stable set of example files to use for test data. They don't need to be big, but still quite a few in number and with us keeping track of exactly what is expected. Even at unit testing level (rather than full plugin integration tests) we still need comprehensive, stable input.

Generate a full test suite based on the current state of the repo. Update AGENTS.md to note that tests must pass, and should be updated when code is added, changed, removed.
