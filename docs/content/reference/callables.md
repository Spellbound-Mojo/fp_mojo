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

Use `as_binary(function)` for a plain binary function or a stored thin pointer.
It creates a `NativeBinary` that consumes two arguments and keeps the native
result and error types. A named adapter works in `zip_with`, `map_with_index`,
`scan_map` and `scan_left`, so the same callback can be reused across operations.
Call it as `combine(left, right)` or `combine.call(left, right)`.
As with `NativeUnary`, `.function()` borrows the stored callable and
`adapter^.into_function()` moves it out. This factory accepts thin functions;
it does not infer capturing closures. A callable struct gives explicit control
over captures and receiver modes.

A procedure with no return value differs from a function returning `NoneType`.
Pipeline and composition mismatch diagnostics name the former
`type_of(None) (no return value)`. Declare an explicit `-> NoneType` result
when the next stage expects a unit payload of that type.

A named `as_unary` adapter can be reused in supported Pipeline, Result and
iterator callbacks, including with noncopyable captures. The example borrows
`formatter` twice and then moves it. See [callback reuse](../start/ownership.md#reuse-callbacks-by-name)
for lifetimes and the distinction between receiver and payload ownership.
The example also reuses one binary adapter to compute running sums and combine
two iterators.
Native functions and closures can still be passed directly when storage as
a library callable is unnecessary.

<!-- example: docs/examples/native_callback_reuse.mojo -->

<!-- api: callables -->
