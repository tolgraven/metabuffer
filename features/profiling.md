# Profiling

And taking action based on the data we get.

The plugin does heavy work in large repos, and we need to tune all hot paths as well as we can. So far we have relied on one-off profiling and done some work, but we want something more thorough and consistent.
Add optional profiling to all the screen tests and unit tests, showing where we're spending CPU time, blocking, waiting.

We will use this both to tune the plugin itself, but also to make the tests go as fast as possible.
