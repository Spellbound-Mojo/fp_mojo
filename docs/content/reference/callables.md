# fp.callables

Use `fp.callables` to define callable structs or adapt a native function or
closure with `as_unary`. For example, a formatter that owns its prefix can
implement a consuming protocol so a `Result` transformation calls it once.
Most calls to other packages accept native functions or closures directly.
[Ownership and errors](../start/ownership.md#keep-callable-state) explains how
each receiver mode treats a callable's state.

<!-- api: callables -->
