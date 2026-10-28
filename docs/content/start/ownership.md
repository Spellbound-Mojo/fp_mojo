# Ownership and errors

FP Mojo uses Mojo's ownership and error conventions. An operation's signature
tells you whether it borrows or consumes a value and which errors it can raise.
The same rules apply to higher-order functions: a pipeline, fold or match
preserves the ownership and error types of its callbacks.

This page explains the conventions used throughout the
[tutorial](../tutorial/pipelines.md). Each reference chapter gives the details
for its operations.

## Read an argument convention

| Spelling | Meaning in these APIs |
|---|---|
| `value: T` | Read-only access for the duration of the call. It is not permission to keep a reference afterwards. |
| `ref value: T` | A reference whose origin can flow into a returned view or reference. |
| `var value: T` | The callee owns the argument. Transfer a local that is not implicitly copyable with `value^`. |
| `mut value: T` | Mutable access under Mojo's exclusivity rules. |
| `deinit self` | A consuming method, such as `Result.map`, `Result.raise_on_err` or `Choice.unwrap`. |
| `value.copy()` | An explicit copy with the type's own copy semantics. It may allocate, or share underlying storage, as the type decides. |
| `ref[origin] T` | A returned reference tied to the named owner. |

A callback may declare read parameters even where the library passes it owned
values: `def twice(value: Int) -> Int` works as a pipeline stage, a fold step or
a map callback, and the value is destroyed after the call. Declare a parameter
`var` only when the callback needs to keep or consume what it receives.

## Know what is borrowed, copied or consumed

- **Borrowing APIs** keep the source value and its origins. They never produce a
  reference that outlives the owner.
- **Consuming APIs** make consumption visible through `var` parameters, `deinit`
  methods or a separately named operation (`fold_owned`, `attempt_once`,
  `fold_owned_once`). Consuming an iterator is not the
  same as consuming the collection it borrows from.
- **Copying APIs** require `Copyable` only when their semantics need a copy,
  for example the snapshots of `scan_left` or the bound
  arguments of `partial`. Copying always means the type's standard copy, not a
  deep clone.
- **References must have a live owner.** References into consumed storage,
  per-call temporary copies or destroyed closures are rejected at compile time.

`fp.match` always borrows. A `Node` is immutable and shared, and a clause
receives copies of the fields it takes as they are, or the results of the ones
it asks to have evaluated. For a `Choice`, `Result` or `Optional`, a clause
receives a reference to the stored constructor or value. To move a value out,
use the type's consuming methods: `Result.fold_owned`, `Choice.unwrap`,
`Optional.take`.

For iteration, pass a native iterator or an owned collection. `fold_left(add, 0,
values^)` consumes the collection, as `iter(values^)` does, and receives owned
elements; `iter(values)` borrows it and yields whatever the standard iterator
yields for a borrowed collection. A collection passed without `^` is an implicit
copy, which Mojo rejects for `List`.

## Keep callable state

An operation that calls a callback repeatedly keeps that one callback for the
whole operation; it does not copy the callback for each element. A composed
function owns its components: move-only components are moved in, and borrowed
components keep their origin restrictions. `partial` is the exception for its
arguments: it stores a copy of each bound argument and passes a fresh copy to
every call.

A *reusable* callable is one that stays valid for later well-typed calls. It
need not be pure or return the same result each time.

Each callable protocol states how its receiver is used:

| Access | Protocol examples | Meaning |
|---|---|---|
| Shared | `Unary`, `Binary`, `Thunk`, `BorrowCallable` | The callable is read; it can be called any number of times. |
| Exclusive | `MutableUnary`, `MutableBinary`, `MutableThunk` | The callable is mutated in place; calls are sequential. |
| Consuming | `OnceUnary`, `OnceBinary`, `OnceThunk`, `BorrowOnceCallable` | The callable is consumed by its single call. |

Argument conventions are independent of receiver access: a shared callable can
consume its arguments, and a consuming callable can borrow them.

## Choose a callback form

Start with a native function or closure. Use a library callable when you need
partial application, composition or a reusable owner for captured state.

| Need | Form | Contract |
|---|---|---|
| Call an existing function or capture local values | Native function or closure | The operation's signature determines whether it borrows or owns the callback. Captured references retain their origins. |
| Bind leading positional arguments | `partial(function, prefix...)` | Copies the bound arguments when built and on every invocation; the remaining arguments are borrowed. Use a closure for keyword binding or owned/mutable remaining arguments. |
| Compose ordinary transformations | `flow(first, second)` or `compose(second, first)` | Passes each whole result to the next stage; `flow` reads left to right. |
| Compute two results from one input | `merge(left, right)` | Requires the same copyable input type; copies once for the left callback and transfers the original to the right. |
| Transform both pair elements | `split(left, right)` | Infers both types, moves both elements, and invokes the callbacks left to right through ordinary composition. |
| Transform one pair element | `first[Other](callback)` or `second[Other](callback)` | Moves the untouched element through without copying it; callback receiver modes, errors and origins are preserved. |
| Apply a binary callback to a pair | `tupled(function)` | Owns the callback, consumes both pair elements without copies, and retains shared, mutable or consuming receiver requirements. |
| Compose functions returning an effect | `kleisli[Family](first).then(second)` | Uses that family's bind: for example, Result stops at Err and Optional stops at absence. |
| Store a native unary callback as a library value | `as_unary(function)` or `as_unary(closure^)` | Owns the callback without changing its argument, result or error types. Shared callback entry points can borrow the adapter later. |
| Store a plain binary function as a library value | `as_binary(function)` or `as_binary(pointer)` | Copies a thin pointer into an adapter with two owned arguments. Supported binary iterator operations borrow a named adapter. |
| Store a binary closure as a library value | `BinarySignature[A, B, R, E].capture(closure^)` | Selects the two input types, result and error before capturing the closure. `E` defaults to `Never`; the adapter retains the closure's ownership and origins. |
| Retain callback state across a counted loop | `fori_loop_mut(lower, upper, body, carry)` | Borrows a named library body exclusively; state remains in the caller, including after an error. |
| Control receiver mutation or consumption explicitly | A callable struct | Implement the shared, mutable or consuming protocol required by the operation. |

A two-stage `flow` or `compose` can combine a plain function or stored thin
pointer with a library stage directly, in either order. For example,
`flow(add, partial(scale, 2))` adds two arguments and scales their sum.
The composition owns the library stage and a copy of the pointer; no callback
runs during construction. Unary capturing closures still use `as_unary` when
stored as composition stages.

Append more stages with `chain^.then(next)`, or chain `.then(...)` calls directly
on a temporary composition. The old chain and the new stage move into the
result; no callback runs and no capture is copied. Receiver capabilities still
follow every stage, including mutable and consuming stages.

For an existing unary chain, `chain^.compose(before)` transfers the same stages
and adds a new first step. It can change the entry to zero, one or two arguments.
Both extension methods preserve state already held by mutable stages and
retain the origins embedded in inputs and outputs.

For immediate application, `pipe(value, first, second)` accepts a plain
function or stored thin pointer beside a shared library stage. It borrows
the library stage for the call, so a named partial remains available afterward.
The [immediate pipeline example](../reference/functions.md#other-pipeline-entry-points)
reuses one surcharge callback with formatting and totaling functions.

These choices do not change the operation. Mapping a callback that returns a
Result keeps that Result as an element; `traverse` gathers effectful results,
and `flat_map` sequences a returned carrier. A lazy `filter_map` removes one
Optional layer. A stored Err is data; a native raised error remains a separate
failure channel.

## Reuse callbacks by name

For operations with shared callback support, pass a named unary `partial`,
`as_unary` adapter, shared unary `flow`/`compose` chain or compatible shared
Kleisli chain directly. The operation borrows the callback without copying its
captures. Pass `callback^` to transfer it through an owned overload. A custom
callable's shared receiver protocol alone does not promise this automatic
adaptation; use the ownership form documented by the operation.

For `zip_with`, `map_with_index`, `scan_map` and `scan_left`, a two-argument partial, shared binary
composition or binary `flip` wrapper supports the same named reuse. The
[indexed mapping example](../reference/iteration.md#prefixes-indexed-mapping-and-consuming-terminals)
uses one partial in both operations.

<!-- example: docs/examples/callback_reuse.mojo -->

`pending` holds shared borrows of `price` and `affordable` without invoking
them. The eager pipeline can use both callbacks while that lazy chain exists.
It keeps prices `3` and `6`; consuming `pending` also keeps `9`. The reduction
then reuses `price` to produce `18`. The final `price^` transfers the partial
into `owned`, which produces `[3, 6]`.

Callback ownership and payload ownership are separate choices:

| Operation in the example | Callback receiver | Input payload |
|---|---|---|
| `map(price)` | Borrowed | Consumed by mapping; Partial's native target reads it during the call |
| `filter(affordable)` | Borrowed | Borrowed by the predicate, then retained or discarded by filtering |
| `map(price^)` | Owned by the iterator | Consumed by mapping |

A unary partial supports both payload conventions. An `as_unary` adapter has
an owned-argument contract, so it cannot replace a borrowing predicate or key
merely because its receiver is reusable. Partial's bound-prefix copies still
occur on every actual native call; callback admission adds no copy.

Keep a borrowed callback alive and unmoved while an iterator, branch handle,
deferred computation or returned view still needs it. An immediate operation
returning an independent value releases the borrow when it finishes. Consuming
or abandoning a lazy operation releases its callback view; owning a callback
through `^` transfers responsibility for destroying it. Moving an owner does
not extend the lifetime of references captured inside it.

The reference for each operation specifies the admitted callback shape,
receiver modes and errors. Lazy callbacks must be non-raising; terminal
operations may propagate their declared native errors. Shared calls can be
repeated; a consuming-only callback cannot be used where an operation needs
multiple calls.

## Keep failure channels apart

The library keeps these outcomes apart:

| Outcome | Representation | Who handles it |
|---|---|---|
| Domain failure | `Result[T, E]` holding `Err[E]` | Result operations, matching or an explicit bridge |
| Callback or projection failure | Native `raises E` | An enclosing `try`/`except` or propagation |
| No applicable clause | Not a run-time outcome: `fp.match` is exhaustive, and a match that leaves a constructor without a clause that cannot decline does not compile | The compiler |
| Iterator exhausted | `StopIteration` raised by the source | The iterator consumer |
| Empty uninitialized reduction | `EmptyReductionError`, or its `ReductionError` alternative | The caller of `reduce` |

The same payload type can travel through different channels. A callback that
raises `String` differs from one that returns `Err[String]`. A callback that
raises `StopIteration` has failed; it has not ended the source. Only the
source's own exhaustion, detected outside the callback, ends iteration.

Every operation follows these rules:

1. Higher-order operations propagate callback failures unchanged. They never
   catch an error silently, turn it into an empty Optional or return `Err`
   unless the operation is an explicit bridge (`attempt`, `attempt_once`,
   `raise_on_err`).
2. The first failure stops the operation: later stages, elements, cases and
   callbacks do not run.
3. Error payloads keep their exact type. Nothing is converted to a string or
   erased.
4. Non-raising callbacks add no error type. An operation that has no other
   source of failure specializes to `raises Never`.
5. Recovery does not roll back side effects that callbacks already performed.
   Owned values and resources are still cleaned up on every failure path.

Operations that combine several callbacks, such as matching, composition and
folds over several callbacks, need one common error type: each participant
raises that type or nothing. To combine different error types, map them
explicitly, for example into a native `Variant`; the library does not infer
error unions.

## Write generic callbacks

Accumulator and element types can differ, and so can the input and output types
of pipeline stages.

A predicate that selects a branch must return a scalar `Bool`. A SIMD mask is
never collapsed silently; reduce it yourself with the standard lane operation you
intend.

Which callable forms an operation accepts (plain functions, capturing closures,
library callables such as `Partial` or `flow(...)`, adapted native signatures) is
stated in its reference chapter. The known compiler exclusions are listed in
[support and limitations](../guides/status.md).

Next, start the tutorial with [eager pipelines](../tutorial/pipelines.md).
