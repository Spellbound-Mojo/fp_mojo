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

Capture a binary closure with `BinarySignature[A, B, R, E].capture(closure^)`.
Select the two input types and result type; `E` defaults to `Never` for pure
callbacks and explicit `raises Never`. A raising callback supplies its error
type as the fourth parameter. The result is the same reusable `NativeBinary`,
with its closure type, copyability and capture origins retained automatically.
The example uses `BinarySignature[Int, Int, String]` for a formatter that owns
its prefix, without naming the closure's generated type or a raising flag.
A closure containing only borrowed references can be passed by name.

Use `BorrowSignature[A, R, E].capture(callback)` to store a native predicate,
observer or projection that reads its payload. For example,
`BorrowSignature[Int, Bool].capture(below)` produces a `NativeBorrow` reusable
by name in `iterated(values).filter(selected)` and `pipeline[Int](values).filter(selected)`.
The callback and its captures belong to the adapter; each invocation only
borrows its payload. Move an owned capture into it with `capture(callback^)`.
This avoids defining a callable struct simply to reuse a captured predicate.

`E` defaults to `Never`; supply the exact error type for a raising callback.
Plain functions, capturing closures and stored thin pointers (including type
aliases) are accepted. Named pointer capture copies the pointer, so reassigning
its source does not change the adapter. Use `.invoke(value)` for a direct call,
`.function()` to borrow the native callback or `adapter^.into_function()` to
recover it. Callbacks that require mutable access to their captures need an
explicit mutable callable or an operation that owns that mutable callback.

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
