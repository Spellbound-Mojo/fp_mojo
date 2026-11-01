"""Functional programming for Mojo.

`from fp import ...` covers everyday code with one import:

- Chains: `pipeline(value)` for eager chains over a value or carrier,
  `pipeline_values(dict)` for dictionary values, `iterated(source)` for lazy
  sequences, and `flow`/`partial` to build functions to call later.
- Results: `Result`, `Ok`, `Err`, and `Capture` to turn a raising call into a
  `Result`.
- Family operations, inferred from the value: `map`, `filter`, `flat_map`,
  `traverse` and `sequence` (eager, from `fp.algebra`).
- Reductions: `fold_map`, `combine_all`, `sum_by` and `find_map`, with the
  canonical monoids `StringMonoid`, `ListMonoid`, `IntSumMonoid` and
  `IntProductMonoid`.
- Error accumulation: `Accumulate` and `ValidationFamily`.
- Matching: `match`, `when` and `rewrite`.

Every name is the same declaration as in its package; import the packages
(callables, functions, adt, data, iteration, control, algebra,
algebra.contracts, effects or matching) for the rest of the library. The lazy
`map` and `filter` of `fp.iteration` stay there; `iterated(source).map(f)` is
the lazy form.
"""

from fp.matching import `match`, rewrite, when
from fp.functions import pipeline, pipeline_values, flow, partial
from fp.iteration import iterated, fold_map, combine_all, sum_by, find_map
from fp.data import Result, Ok, Err, Capture
from fp.algebra import map, filter, flat_map, traverse, sequence
from fp.algebra import StringMonoid, ListMonoid, IntSumMonoid, IntProductMonoid
from fp.algebra import Accumulate, ValidationFamily
