# fp.callables

You need `fp.callables` when you write your own callable struct, such as a
formatter that a `Result` transformation consumes once, or when you promote a
closure with `as_unary` so that it can be a pipeline stage. Code that passes
plain functions and closures to other packages does not import it.
[Ownership and errors](../start/ownership.md#keep-callable-state) explains how
each receiver mode treats a callable's state.

<!-- api: callables -->
