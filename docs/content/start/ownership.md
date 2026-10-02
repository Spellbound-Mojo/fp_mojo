# Ownership and errors

FP Mojo uses Mojo's own ownership and error conventions. Function signatures
provide exhaustive information about ownership, retention, and error handling.

## Argument conventions

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

## Borrowing, copying and consuming

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

## Callable state

As a general rule, an algorithm that calls a callback repeatedly keeps that one callback for the
whole operation as opposed to copying the callback per element and composed function
owns its components, meaning move-only components are moved in, borrowed components keep
their origin restrictions.

**However, there is an exception: `partial`  stores a copy of each bound argument and passes a fresh copy to every call.**

In this library, by "reusable" callable we mean a callable that stays valid for later well-typed calls. Please note it does not
mean that the callback is pure or returns the same result each time.

Each callable protocol states how its receiver is used:

| Access | Protocol examples | Meaning |
|---|---|---|
| Shared | `Unary`, `Binary`, `Thunk`, `BorrowCallable` | The callable is read; it can be called any number of times. |
| Exclusive | `MutableUnary`, `MutableBinary`, `MutableThunk` | The callable is mutated in place; calls are sequential. |
| Consuming | `OnceUnary`, `OnceBinary`, `OnceThunk`, `BorrowOnceCallable` | The callable is consumed by its single call. |

Argument conventions are independent of receiver access: a shared callable can
consume its arguments, and a consuming callable can borrow them.

## Failure channels

We distinguish the following sources of failures:

| Outcome | Representation | Who handles it |
|---|---|---|
| Domain failure | `Result[T, E]` holding `Err[E]` | Result operations, matching or an explicit bridge |
| Callback or projection failure | Native `raises E` | An enclosing `try`/`except` or propagation |
| No selected case | Empty outer `Optional[R]`, or the fallback | The caller of partial matching |
| Iterator exhausted | `StopIteration` raised by the source | The iterator consumer |
| Empty uninitialized reduction | `EmptyReductionError`, or its `ReductionError` alternative | The caller of `reduce` |

Note that equal payload types can still have different mechanisms for raising errors.
For example, a callback that raises `String` differs from one that returns `Err[String]`.
Importantly, a callback that raises `StopIteration` is a callback failure, not the end of the source. 
Source exhaustion is detected by callbacks run outside the boundary.

The rules every operation follows:

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

**Operations that combine several callbacks (matching, composition,
folds over several callbacks) need one common error type. Each participant must
raise that type or nothing. If you need different error types, you can map them
explicitly, for example into a native `Variant`; the library does not infer error unions.**

## Generic callbacks

Accumulator and element types can differ, and so can the input and output types of pipeline stages.

A predicate that selects a branch must return a scalar `Bool`. A SIMD mask is
never collapsed silently; reduce it yourself with the standard lane operation you
intend.

Which callable forms an operation accepts (plain functions, capturing closures,
library callables such as `Partial` or `flow(...)`, adapted native signatures) is
stated in its reference chapter. The known compiler exclusions are listed in
[support and limitations](../guides/status.md).
