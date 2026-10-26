# fp.callables

Use `fp.callables` to define callable structs or adapt a native function or
closure with `as_unary`. For example, a formatter that owns its prefix can
implement a consuming protocol so a `Result` transformation calls it once.
Most calls to other packages accept native functions or closures directly.
[Ownership and errors](../start/ownership.md#keep-callable-state) explains how
each receiver mode treats a callable's state.

`as_unary` also accepts a stored thin function pointer without extra type
arguments. For example, both a declaration `increment` and a variable declared
as `var step: def(var Int) thin -> Int = increment` can be adapted with
`as_unary(step)`. The adapter owns a copy of that pointer; reassigning `step`
does not change the adapter. Its argument, return and error types remain exact,
including `raises Never` and no-value returns. Native pointers remain implicitly
copyable; captured closures retain their own copyability and borrowed origins.
Creating an adapter never invokes the callback.

<!-- api: callables -->
