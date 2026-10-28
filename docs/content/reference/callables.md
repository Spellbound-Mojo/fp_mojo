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

A named `as_unary` adapter can be reused directly in Pipeline and Result
callbacks, even when its captured values cannot be copied. These operations
borrow the adapter; they neither copy its captures nor extract its function.
Use `callback^` to transfer ownership. Deferred operations keep the borrow
until they run or are discarded, so keep the adapter alive for that duration.
Native functions and closures can still be passed directly when storage as
a library callable is unnecessary.

<!-- example: docs/examples/native_callback_reuse.mojo -->

<!-- api: callables -->
