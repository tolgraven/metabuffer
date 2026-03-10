# Integration testing

We also need to test the entire plugin in a real world enviroment. So far agents have generated new example data and files for each such test, but we want something more available, stable, reliable.

Generate a full test suite for common behavior, including but not limited to filtering an open file with `:Meta`, passing a query to `:Meta`, project mode with `:Meta!`, sending real input char by char and observing state. Also add debug logic so that results buffer can be automatically written to tmp on each input or action.

Based on:
## mini.test

This is probably the best current choice for a new plugin unless you have a reason not to. It supports:
	•	child Nvim process management
	•	hierarchical tests
	•	hooks
	•	parametrization
	•	filtering
	•	screen tests
	•	busted-style emulation

That combination makes it closer to a purpose-built Neovim plugin test framework than older ad hoc setups.  ￼

https://github.com/nvim-mini/mini.test
