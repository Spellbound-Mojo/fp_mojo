"""Lazy adapters, folds, reductions and terminal operations over native iterators.

Every operation consumes a **source**: a native iterator, used as it is and
never restarted, or an owned collection (any `IterableOwned`, such as `List`,
`Set` or `Dict`), consumed as `iter(values^)` would. Pass `values^` to consume
a collection, or `iter(values)` to borrow it. Standard adapters (`chain`, `zip`,
`enumerate`, `take`, `drop`, `peekable`, ...) come from `std.iter` and
`std.itertools` and combine freely with these.

**Lazy adapters** (`map`, `filter`, `filter_map`, `flatten`, `flat_map`,
`scan_left`) are native iterators whose advancement raises only
`StopIteration`:

- Construction is inert: nothing is pulled and no callback runs until the first
  `next`.
- They are fused: after a source reports exhaustion it is never pulled again.
- There is no lookahead: each output pulls only what it needs.
- Abandoning one destroys its owned state without evaluating the rest.

Lazy callbacks do not raise, because a native iterator can raise only
`StopIteration`; to carry a domain failure, yield `Result` elements and
aggregate them with `collect_results`. A callback is a plain function, a
capturing closure or, for `map`, `filter_map`, `flat_map` and `scan_left`, a
shared-receiver `Unary`/`Binary` value such as a `Partial`. Move a closure that
owns non-trivial state in with `callback^`. Owners of borrowed captures must
stay alive and unmoved while the adapter is used. A generic function that
returns an adapter names its type with `MapIterator`, `ScanIterator`,
`FilterIterator`, `FilterMapIterator` or `FlatMapIterator`, declares
`I: Iterator` and `where I.Element == T`, and builds the value through the
function; the types add no storage, and the source origin stays part of the
type.

**Folds and terminals** (`fold_left`, `fold_until`, `reduce`,
`reduce_optional`, `collect_list`, `find`, `any`, `all`) run at once:

| Operation | Non-empty input | Empty input |
|---|---|---|
| `fold_left(step, initial, source)` | `n` calls of `step(var A, var T) -> A`, in order | `initial`, no calls |
| `reduce(step, source, initial=value)` | The same as `fold_left` | `initial`, no calls |
| `reduce(step, source)` | The first element seeds the accumulator; `n - 1` calls | Raises `EmptyReductionError` |
| `reduce_optional(step, source)` | As above, wrapped in `Optional` | `None` |
| `fold_until(step, initial, source)` | Each call returns `ControlFlow[B, A]`; `Break(b)` returns at once | `Continue(initial)` |
| `collect_list(source)` | A `List` of every element, moved | An empty list |
| `find(p, source)` | The first accepted element | `None` |
| `any(p, source)` / `all(p, source)` | Stops at the first decisive element | `False` / `True` |

Steps are never reassociated. Pure and raising callbacks have separate
overloads, and a callback's error type propagates unchanged; a callback that
raises `StopIteration` fails as a callback, never as exhaustion. The first
decisive result or failure stops without another pull. On failure, native
cleanup destroys the source, the current accumulator and the pulled element;
side effects are not rolled back. Every operation makes `O(n)` callback calls,
or fewer after an early stop, with constant extra state.

A generic function forwards to these with the native callback constraint and
`where I.Element == T`. A raising wrapper passes `E=E` at every call and must
not read `F.E` or `F.T` from a callback type: Mojo 1.1 does not reliably expose
those attributes through a precompiled package. Keep the parameter names shown
in the tutorial's generic examples; on Mojo 1.1 some renamings lose callback
conformance.
"""

from .adapters import (
    FilterIterator,
    FilterMapIterator,
    FlatMapIterator,
    MapIterator,
    ScanIterator,
    all,
    any,
    collect_list,
    filter,
    filter_map,
    find,
    flat_map,
    flatten,
    map,
    scan_left,
)
from .folds import (
    EmptyReductionError,
    ReductionError,
    ReductionStepError,
    fold_left,
    fold_until,
    reduce,
    reduce_optional,
)
