# Visuals

We want to have some cool terminal tricks.

## Animated text with a "loading" rolling gradient

- Codex-style ("Working" having a dark gradient roll across the word to indicate active work/loading) - we should use this somewhere in the prompt, would make delays much less jarring.

## Opacity fade

- Since floating windows have winblend, we should fade them in over half a second or so (smoothly) (initial invocations, not for auto resume when cycling buffers with `C-o` or similar, need speed then). Info window should also slide in from right, while opacity increases.
  - We should be able to do this since most of our time is spent waiting regardless, just perhaps need more fine-grained asyncness and yields (schedule chunks of work and return to render frame, then next chunks...)
- Prompt window should "slide up" (expand from 1 to n rows smoothly (remember to temp override minwinheight for this)) from bottom, and preview window slide in (expand) from right.

## Dummy overlaid mirroring windows with covering loading animation
- Should performance require it, in project mode on large repos we might want to quickly put in dummy floating windows on top of the incoming real ones, covering them and with some loading animation, then after the windows underneath are in place and populated, quickly fade out and reveal. Combine this with stuff from line 6-8

## Smooth scrolling of results buffer with `<C-d` etc

- We should use the approximate logic from /Users/tol/CODE/VIM/proper-smooth.nvim for these animated scrolls.

