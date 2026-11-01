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
| `r.fold_once` / `r^.fold_owned_once` | Explicit forms consuming both handlers; ordinary folds also accept owners | |
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
when the program compiles and allows guards. Ordinary `fold` and `fold_owned`
accept borrowed, owned and mixed library handlers; `_once` methods explicitly
consume both. Each owned handler may have a shared, mutable or consuming receiver. The existing one-call dispatch selects consuming, then
mutable, then shared; `mut_ref` retains state without changing branch selection.
Both handlers must be invocable even when one branch is inactive.

### Derived Result combinators

Result methods and their Pipeline counterparts share execution. The Pipeline
methods forward to the Result family; they never inspect its tag.
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
All library forms of `fold_owned` delegate to `fold_owned_once`. Borrowed
handlers become the existing `_SharedUnaryRef`; owners move through unchanged.
Likewise, library `fold` forms delegate to `fold_once` using `_SharedBorrowRef`
for borrowed handlers. These views retain their original origins and shared
receiver choice. They introduce no copying or allocation, and both mixed
ownership combinations use the same execution owner. Native signatures keep
their existing admission and invocation bridges. Single-branch transformations provide a callback for the active
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
public `invoke_borrowed_once` prefers `BorrowOnceCallable`, then
`BorrowMutableCallable`, then `BorrowCallable`;
Reader endpoints and `local` use that same dispatch. Result's leaf module does
not depend on algebra instances, which already depend on Result. Its adapters
supply the native Result mapping boundary while the callable helpers remain
independent of the container.

Native admission signatures are generated from
`scripts/generate_result_syntax.py`. Native borrowing endpoints use one
reference view with a direct call to the shared native helper. Mojo 1.2 no
longer needs separate invocation functions for differently named callbacks.
Removing the extra function-valued dispatch layer also avoids the observed O0
Bool corruption when that layer forwards through the shared helper. Factories
use the shared thunk view and `_IgnoreInput`, preserving payload retention in
the existing Result adapters.
Native owned transformations retain Result's existing
invocation boundary. Conditional continuations use its owned context form:
library callbacks move into that context, while native callbacks enter by
pointer with their admitted signature. This avoids requiring a capturing
native invocation to conform to a non-capturing `Unary` method on Mojo 1.1.
These adapters preserve exact input, output, error and
origin types and contain no independent branch implementation.

The two-branch native methods spell input types from the source, and
`redeem_with` spells its Result output structurally. Relationships between embedded origins are checked
in public signature constraints, including the common native error type and
`attempt_tap`'s stored error type; body assertions alone cannot enforce those
relationships on Mojo 1.1.

The operations execute eagerly, use constant auxiliary space, and allocate no
container storage beyond the existing Result or tuple; callbacks determine
additional work and allocation. Native errors stay native. Operations with two
callbacks accept only one common native error type or a non-raising callback
alongside it. Retained values cannot borrow from a callback's temporary storage,
and two callbacks with conflicting mutable captures remain invalid native calls.

Native Result transformations and folds infer callback result types separately
from the requested output type, then require exact equality including origins.
Both fold branches must match the requested result. Invocation uses each
callback's actual signature, and the existing branch and transformation drivers
still own execution. This avoids Mojo 1.2 inference crashes for incompatible
output origins while preserving positional callback/error bindings.

### Bridges between raised and stored failures

| Bridge | Behavior |
|---|---|
| `Capture[E]()...run(f)` | Binds arguments with their native conventions, calls `f` once and returns `Ok(result)` or `Err(error)`, catching only the declared error type |
| `Capture().run(thunk^)` | The same for any invocable library thunk, called once through `call_once` |
| `raise_on_err(r^)` / `r^.raise_on_err()` | Returns the value or raises the stored error with its original type |
| `collect_results(iterator)` | `Ok(List[T])` of the successes in order, or the first `Err`; stops pulling at the first `Err`. It takes a native iterator, such as `iter(results^)` or a lazy `map` |

`Capture` binds arguments before callback admission: `args`, `borrow`,
`mutable`, `take` and `kwargs` fix each operand's type and convention, so no
convention selector or callback-type hint is needed. Each bound call becomes a
private `_BoundThunk` that the private one-shot engine
`fp.data._attempt._attempt_once` runs. That engine accepts `ThunkContract`
metadata with any receiver mode, so library thunks passed to `run` use the
same path. Execution delegates to `call_once`, preserving consuming-first
selection and mutable-before-shared fallback. `_attempt_core` remains the sole
conversion from a raised failure to Result. The optional pending owner is
emptied before invocation, preserving move-only cleanup. `mut_ref(thunk)`
consumes only its reference and leaves original state available, and
generic forwarding retains `Result[F.Out, F.Error]`. Mutations a target made
before failing remain visible; capture does not catch process termination or
unrelated failures. See the
[call forms](../reference/data.md#select-a-native-argument-convention).

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

## Non-empty storage stays below algebra

`data.non_empty_list.NonEmptyList` owns only the non-empty invariant and native
List storage. Public construction either supplies a first element or checks an
existing List. The checked constructor is the single validation point;
`from_list` translates its empty-input error into None. No mutable List view,
empty constructor or removal method can invalidate the invariant. Internal
underscore fields are outside the supported API, as with Result storage.

Singleton construction has its own overload: a default empty tail would carry
T's origins and introduce a false alias for mutable borrowed elements. The
checked List constructor uses the keyword `values` so a List may also be the
sole element of a nested NonEmptyList without overload ambiguity.

`first` preserves the native List element origin. Buffer transfer and consuming
iteration are constant time; constructing from a head and tail and concatenation
move elements in linear time. Copying is conditional on element Copyable.

The upper `algebra.non_empty` module supplies the family and Semigroup. Mapping
and traversal reuse ListFamily and the target Applicative's existing collection
kernel, then restore the proven non-empty shape in each successful branch.
Third-party targets must obey the Traversable shape laws. Filtering deliberately
returns List. No validation policy or callback loop is added to the carrier.

### Migration from the first nightly fluent API

Use `pipeline(value^).map2(other^, combine).get()` in place of direct Result
`map2`; the same move applies to `product`, `ap`, `map_n`, `product_n`,
`par_map_n`, `par_product_n` and `if_effect`. Core Result transformations,
including outcome observation and recovery, remain consuming Result methods.
These adapters use callable kernels below algebra; Result imports no algebra
module. Generic `map2` wrappers forward `Map2Contract` from
`fp.algebra.contracts`.

## Inclusive-or reuses Choice

`Ior[E, A]` is an alias for `Choice[_IorCases[E, A]]`, with constructors
Left, Right and Both. Choice owns storage, conditional copying, tag access,
consuming extraction and the interface used by exhaustive matching. There is
no second sum implementation or matching engine. The carrier adds no heap
allocation and accepts move-only fields and embedded native origins.

The leaf `data.ior` knows only the constructors and their structural
projection/reconstruction. Internal owned Optional slots represent presence of
diagnostics and a value; at least one is always present. Consuming constructor
methods move fields into those slots, and one consuming split boundary moves
them out, because native tuples do not provide movable indexed references.
Each constructor exposes consuming `into_payload`; Both returns a native pair.
Its internal projection reuses the shared native pair extraction helper.
No callback, Semigroup or accumulation policy is imported by the carrier.
`algebra.ior` owns transformations and the two evaluation policies.

Immutable borrowed payloads and diagnostics retain their precise origins through
mapping and binding. Mutable borrowed payloads can be stored and accessed.
Mojo rejects a callback whose type embeds the same exclusive origin as a
simultaneously passed argument; Ior does not relax native alias checking to
admit that callback. Compile-failure fixtures cover payload and diagnostic
origin mismatches as well as exclusive-origin callback aliases.


Ordinary Result folds separate the payload's ownership from the handlers'
ownership. This keeps one operation name for branch selection while using
Mojo's argument conventions to retain or transfer each handler. Only the chosen
handler runs, but both must be invocable. Consumed inactive handlers are still
destroyed; borrowed originals remain available after either branch or an error.
The common error assertions and receiver availability checks remain in the
existing `_once` owners. Their diagnostic prefix is `Result fold:` for both
ordinary and explicit consuming forms.
