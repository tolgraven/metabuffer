This is the main feature of the plugin and will require finesse.
<M-CR> should close prompt window, but keep our results buffer open and move to its window.
We can then edit the buffer, and every change made should (on write, so we need to trick vim somehow to let it "write" without a filename)
result in the original files where the hits are from also being changed.

We should also be able to open Meta again, even on such a results buffer, and make further search refinements.
