# Result, Optional and ControlFlow

`fp.data` holds the concrete functional data types: `Result` for typed success
or failure and `ControlFlow` for early termination. Both are non-recursive
algebraic data types stored in place, like a user's
[`Choice`](matching.md#values-stored-in-place), and `fp.match` matches them
like any other data value. The standard `Optional` is matched directly; the
library adds no Maybe type.

## Result

```text
Result[T, E] = Ok(T) | Err(E)
```

`Result` stores a native `Variant[Ok[T], Err[E]]`. The constructor wrappers
keep the two cases distinct even when `T` and `E` are the same type, which a
plain `Variant[T, E]` could not do. A payload is reached only after a case check
or through exhaustive elimination: a method, or `fp.match` with clauses for
`Ok[T]` and `Err[E]`. There is no unchecked unwrap and no reinterpreting cast.
`Result` is `Copyable` only when both `T` and `E` are.

Mojo already has typed native errors, and they are efficient. `Result` is a data
representation for failures that must be stored, collected or passed along as
values, not a replacement for `raises`.

### Operations

Transformations are methods that consume the Result, so they chain. To keep the
original, copy it explicitly.

| Method | On `Ok(value)` | On `Err(error)` |
|---|---|---|
| `r^.map(f)` | `Ok(f(value))` | `Err(error)`, `f` not called |
| `r^.flat_map(f)` | `f(value)`, a `Result[U, E]` | `Err(error)`, `f` not called |
| `r^.map_err(g)` | `Ok(value)`, `g` not called | `Err(g(error))` |
| `r^.or_else(g)` | `Ok(value)`, `g` not called | `g(error)`, a `Result[T, F]` |
| `r.fold(on_ok, on_err)` | `on_ok` borrows the value | `on_err` borrows the error |
| `r^.fold_owned(on_ok, on_err)` | `on_ok` receives the value | `on_err` receives the error |
| `r.fold_once` / `r^.fold_owned_once` | As above, consuming both handlers and calling only the selected one | |
| `r.is_ok()`, `r.is_err()` | Case test | |

All four methods run through one owned transformation that branches on the
stored case. The algebra's `map[ResultFamily[E]]` and `flat_map[ResultFamily[E]]`
call the same methods, so code generic over instances and code that knows it
holds a Result share one implementation. `flat_map` keeps the stored error type,
so combining different error types needs an explicit `map_err`. `Ok` and `Err`
convert implicitly to a Result whose type is known, so functions write
`return Ok(value)`. `map` keeps a returned `Result` as nested data.

Two rules hold for every operation:

1. A callback never runs on the inactive case.
2. A native error raised by a callback stays a native error. It is never turned
   into the Result's `Err`, even when the types coincide.

A callback can be a native function or closure, a fixed-arity library callable
such as a partial, or a `BorrowCallable` for borrowed folds. Folds take
capturing callbacks, which `fp.match` clauses cannot; a match checks every case
when the program compiles and allows guards. `fold_once` and `fold_owned_once`
consume both handler owners, call only the selected one and let native
destruction release the other.

### Bridges between raised and stored failures

| Bridge | Behavior |
|---|---|
| `attempt(f, args...)` | Calls `f` once and returns `Ok(result)` or `Err(error)`, catching only `f`'s declared error type |
| `attempt_once(thunk^)` | The same for a consuming `OnceThunk`, called once |
| `raise_on_err(r^)` / `r^.raise_on_err()` | Returns the value or raises the stored error with its original type |
| `collect_results(iterator)` | `Ok(List[T])` of the successes in order, or the first `Err`; stops pulling at the first `Err`. It takes a native iterator, such as `iter(results^)` or a lazy `map` |

`attempt` accepts native functions with zero to two positional arguments, with
read, owned or `mut` conventions, and targets that declare a native keyword pack
`var **kwargs: K` (homogeneous values or a `StringDict[K]` expansion), with zero
to two positional prefixes. Mutations a target made before failing remain
visible. The error type must be stated or inferred exactly; `attempt` never
catches process termination or unrelated failures.

`collect_results` performs no validation accumulation: an accumulating
validator would be a different operation from short-circuiting `Result`
sequencing. Empty input gives `Ok` of an empty list.

## Optional

The library adds no Maybe type. `fp.match` takes a standard `Optional[T]`
directly: a clause takes `T` for a present value, which it borrows, `NoneType`
for an absent one, or `Optional[T]` as a catch-all. The standard `Optional`
owns the value, and its methods (`map`, `and_then`, `or_else`, `take`) keep
their standard meanings. A generic function cannot name `Optional`'s element
type, so the matcher recognizes the type by name and takes `T` from the clause
that names it.

## ControlFlow

```text
ControlFlow[B, C] = Break(B) | Continue(C)
```

`ControlFlow` separates intentional early completion from failure. `fold_until`
steps return it, and every terminal iteration operation uses it internally to
stop (see [iteration](iteration.md#terminal-driver)). It is a `Choice` of the
constructors `Break[B]` and `Continue[C]`: a step returns `Break(value)` or
`Continue(value)`, which convert to it, and the result is inspected with
`isa`, indexing, `unwrap` or `fp.match`.

## Consuming access

`fp.match` only borrows. Consumption stays with the types: `Result`'s
`fold_owned`, `raise_on_err` and transformations move the payload out,
`Choice.unwrap` moves the constructor out, and `into_payload` moves the value
out of an `Ok`, `Err`, `Break` or `Continue`. The consuming folds hold each
handler in its own parameter and call only the selected one; the other is
destroyed with the frame. These are plain branches on the stored case, with no
handler objects or context descriptors.
