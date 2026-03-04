Neovim can conceal entire lines using Treesitter.
We should investigate using that instead of raw filtering, at least for smaller sets.
It should be able to help us easier dynamically introduce hit context into the metabuffer, and we'll rely heavily on treesitter for that anyways.
