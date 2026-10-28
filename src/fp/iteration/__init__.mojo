"""Lazy adapters, folds, reductions and terminal operations over native iterators.

Every operation consumes a **source**: a native iterator, used as it is and
never restarted, or an owned collection (any `IterableOwned`, such as `List`,
`Set` or `Dict`), consumed as `iter(values^)` would. Pass `values^` to consume
a collection, or `iter(values)` to borrow it. Standard adapters (`chain`, `zip`,
`enumerate`, `take`, `drop`, `peekable`, ...) come from `std.iter` and
`std.itertools` and combine freely with these.

`iterated(source)` adds consuming method syntax to the same native iterators:
`iterated(values^).map(f).filter(p).to_list()`. Its `Iter` wrapper implements
`Iterator` and `IterableOwned`, so standard consuming adapters accept it
directly. Native `take`, `drop`, `enumerate`, variadic `zip` and `chain` are
also consuming methods. Wrap another standard adapter's result with `iterated`
to continue chaining.
`to_list()` and `collect_list()` are alias methods for the free `collect_list`.
Named chains are consumed explicitly, as in `stream^.to_list()`.
The core functions `map`, `filter`, `filter_not` and `fold_left` are also exported by
`fp.combinators`; both imports refer to the same native functions. `Piped` adds
the same named methods to eager value chains. Its fold keeps the accumulator
inside the chain, while `Iter.fold_left` returns the accumulator directly.

**Lazy adapters** (`map`, `filter`, `filter_not`, `filter_map`, `flatten`, `flat_map`,
`scan_left`, `zip_with`, `map_with_index` and value-taking `take_while`/`drop_while`)
are native iterators whose advancement raises only
`StopIteration`:

- Construction is inert: nothing is pulled and no callback runs until the first
  `next`.
- They are fused: after a source reports exhaustion it is never pulled again.
- There is no lookahead: each output pulls only what it needs.
- Abandoning one destroys its owned state without evaluating the rest.

Lazy callbacks do not raise, because a native iterator can raise only
`StopIteration`; to carry a domain failure, yield `Result` elements and
aggregate them with `collect_results`. A callback is a plain function, a
capturing closure or a library callable such as a `Partial`. `map`, `filter_map`
and `flat_map` accept shared or mutable unary receivers; `scan_left` accepts
shared or mutable binary callbacks. Move a closure that
owns non-trivial state in with `callback^`. On Mojo 1.1, some native closures
with move-only inputs/output and owned mutable state require `@always_inline`
on the callback to preserve state writes at O3; see the native-boundaries
architecture chapter. Owners of borrowed captures must
stay alive and unmoved while the adapter is used. A generic function that
returns an adapter names its type with `MapIterator`, `ScanIterator`,
`FilterIterator`, `FilterNotIterator`, `FilterMapIterator` or `FlatMapIterator`, declares
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
| `first(source)` / `last(source)` | First / last remaining element | `None` |
| `is_empty(source)` | Pulls at most one value; returns `False` | `True` |
| `count(source)` / `count_where(p, source)` | Visits and counts values / matches | `0` |
| `contains(source, value)` | Borrows for equality, stops at first match | `False` |
| `for_each(f, source)` | Moves each value into a callback returning `NoneType` | `None`, no calls |
| `to_non_empty_list(source)` | `Some(NonEmptyList)` | `None` |
| `combine_all_optional[S](source)` | Left-to-right Semigroup reduction | `None` |
| `collect_fold[M](f, source)` | Combines present Optional results with the Monoid | Monoid identity |
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
    FilterNotIterator,
    FilterMapIterator,
    FlatMapIterator,
    MapIterator,
    ScanIterator,
    all,
    any,
    collect_list,
    filter,
    filter_not,
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
from .chaining import Iter, iterated
from .derived import fill, replace, void, tuple_left, tuple_right, pair_with, tap_each, compact, traverse, sequence, traverse_void, traverse_tap, sequence_void, flat_traverse, flat_sequence, traverse_filter, filter_effect, sequence_filter
from .reductions import find_map, fold_map, combine_all, sum, sum_by, min_by, max_by

from fp.iteration.effectful import fold_effect, any_effect, all_effect, find_effect, find_map_effect, fold_map_effect

from .prefixes import TakeWhileIterator, DropWhileIterator, take_while, drop_while
from .indexed import ZipWithIterator, IndexedMapIterator, zip_with, map_with_index
from .terminals import first, last, is_empty, count, count_where, contains, for_each, to_non_empty_list, combine_all_optional, collect_fold

from .branching import Unbounded, BoundedFail, BufferCapacityError, BufferLimitExceeded, PartitionBranches, PartitionMapBranches, UnzipBranches, partition, partition_map, unzip

from .alignment import AlignIterator, AlignWithIterator, PadZipIterator, align, align_with, pad_zip

from .scans import ScanMapIterator, scan_map

from .non_empty import reduce_non_empty, reduce_map, combine_non_empty, minimum_by_non_empty, maximum_by_non_empty
