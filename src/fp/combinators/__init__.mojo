"""Direct combinators shared with fluent pipelines.

Collection operations re-export fp.iteration; if_effect re-exports fp.algebra.
Sources are native iterators
at their current position, or owned iterables consumed into their iterators.
Transformations are lazy and require non-raising callbacks. Searches, folds,
sums and effectful traversal are terminals, preserving their exact errors.
Effectful reductions use a Monad target; if_effect selects a factory from an
effectful Bool. Reader and State targets defer execution until run.

Piped offers the same names with eager native container behavior; Iter offers
lazy transformations and immediate terminals. Mapping conveniences share element
adapters, and reductions share the accumulation driver. Native Piped dictionary
transformations and monoidal reductions use values; effectful folds and
predicates follow native iteration, as fold_left does; direct operations follow the source's native iteration.
Whole-value tap is available on Piped, including for ordinary structs.
"""

from fp.iteration.adapters import map, filter, filter_not, filter_map, flat_map, flatten
from fp.iteration.folds import fold_left
from fp.iteration.derived import fill, replace, void, tuple_left, tuple_right, pair_with, tap_each, compact, traverse, sequence, traverse_void, traverse_tap, sequence_void, flat_traverse, flat_sequence, traverse_filter, filter_effect, sequence_filter
from fp.iteration.reductions import find_map, fold_map, combine_all, sum, sum_by, min_by, max_by

from fp.iteration.effectful import fold_effect, any_effect, all_effect, find_effect, find_map_effect, fold_map_effect
from fp.algebra.conditional import if_effect
