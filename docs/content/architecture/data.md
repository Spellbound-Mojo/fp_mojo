# Result, Optional and ControlFlow

`fp.data` provides `Result` for typed success or failure and `ControlFlow` for
early termination. Both are non-recursive algebraic data types stored in place,
using the same representation as a user's
[`Choice`](matching.md#values-stored-in-place). `fp.match` handles their
constructors and also accepts Mojo's standard `Optional` directly.

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

Use `Result` when failures need to be stored, collected or passed along as
values. Mojo's typed `raises` remains available for exception propagation, and
the bridges below convert between the two representations explicitly.

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

### Derived Result combinators

Result methods and their Piped counterparts share execution. The Piped methods
recover the native Result type and forward; they never inspect its tag.
`flat_tap` and `flat_pair_with` bind a borrowing projection and map its success
with a consuming retention adapter. This moves the retained value once, so a
move-only payload needs no copy. An inner failure releases the retained value.
`followed_by` adapts a factory into a continuation; `before` combines that
adaptation with retention. Neither factory runs on an initial error.

`ensure`, `recover_if` and `or_else_if` share one conditional continuation. It
borrows the selected payload for a predicate, then either retains that payload
or consumes it in the continuation. For `ensure`, a borrowed error factory
enters through the existing owned-to-borrowed callable adapter. For selective
recovery, an accepted error moves directly into the recovery. `tap_err` uses
the existing error mapping with an observation adapter. `flat_tap_err` reuses
the retention adapter, restoring `Err` on observer success and propagating an
observer failure. `recover` selects the error branch but wraps its
replacement in `Ok`: the shared transformation primitive selects the output
constructor independently of the input branch.

`_fold_result_owned` owns the tag selection, payload movement, unused context
disposal and native error propagation for consuming folds and transformations.
`fold_owned` supplies borrowed handler contexts; `fold_owned_once` supplies
owned handlers. Single-branch transformations provide a callback for the active
branch and a constructor-preserving callback for the other branch. Borrowing
folds keep their separate borrow boundary, since they do not extract or destroy
the source payload.

`map_both`, `redeem` and `redeem_with` use this same owned fold with two
continuations. The shared `_transformed` helper wraps their outputs in the
selected constructor, wraps either output in `Ok`, or accepts the returned
Result unchanged. Only the source tag selects a continuation, so a returned
error cannot accidentally trigger recovery a second time. `attempt_tap`
extends the existing retention adapter to own the whole Result: observer success
returns that retained Result, and observer failure replaces it.

The callable layer owns borrowed receiver dispatch and payload retention. Its
one-call dispatch prefers `BorrowOnceCallable`, otherwise `BorrowCallable`;
Reader endpoints and `local` use that same dispatch. Result's leaf module does
not depend on algebra instances, which already depend on Result. Its adapters
supply the native Result mapping boundary while the callable helpers remain
independent of the container.

Native admission signatures are generated from
`scripts/generate_result_syntax.py`. A native borrowing endpoint can supply
its invocation to the existing borrowed-reference adapter. This preserves the
signature at admission when Mojo 1.1 cannot reconstruct a second callback's
native witness later. Existing callers keep the direct native bridge: routing
its default through an extra function-valued parameter corrupts Bool predicates
at O0 on Mojo 1.1. The eager filtering example covers that boundary.
Native owned transformations retain Result's existing
invocation boundary. Conditional continuations use its owned context form:
library callbacks move into that context, while native callbacks enter by
pointer with their admitted signature. This avoids requiring a capturing
native invocation to conform to a non-capturing `Unary` method on Mojo 1.1.
These adapters preserve exact input, output, error and
origin types and contain no independent branch implementation.

The two-branch native methods spell input types from the source, and
`redeem_with` spells its Result output structurally. Piped forwards that output
type evidence explicitly. Relationships between embedded origins are checked
in public signature constraints, including the common native error type and
`attempt_tap`'s stored error type; body assertions alone cannot enforce those
relationships on Mojo 1.1.

The operations execute eagerly, use constant auxiliary space, and allocate no
container storage beyond the existing Result or tuple; callbacks determine
additional work and allocation. Native errors stay native. Operations with two
callbacks accept only one common native error type or a non-raising callback
alongside it. Retained values cannot borrow from a callback's temporary storage,
and two callbacks with conflicting mutable captures remain invalid native calls.

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

`collect_results` sequences Results and stops at the first `Err`; it does not
accumulate validation errors. Empty input gives `Ok` of an empty list.

## Optional

`fp.match` accepts the standard `Optional[T]` directly. A clause takes `T` for
a present value, which it borrows, `NoneType` for an absent one, or `Optional[T]`
as a catch-all. The standard `Optional`
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
