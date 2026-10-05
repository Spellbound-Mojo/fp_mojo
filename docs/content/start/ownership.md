# Ownership and errors

FP Mojo uses Mojo's own ownership and error conventions, so a signature tells
you what an operation borrows, keeps, consumes and raises. This page explains
how those conventions apply to library calls and callbacks, and how the library
keeps stored failures, raised errors and the end of an iterator apart. Read it
before the [tutorial](../tutorial/pipelines.md); each reference chapter states
the details for its own operations.

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
- **No hidden copies.** An operation requires `Copyable` only when its
  semantics need a copy, for example the snapshots of `scan_left` or the bound
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
4. A non-raising specialization stays non-raising: pure callbacks produce a
   `raises Never` (non-raising) result.
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
