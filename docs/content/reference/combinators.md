# fp.combinators

Named methods remove wrapper lambdas and intermediate type aliases from
collection pipelines. `Pipeline` keeps eager results in the chain; `Iter` keeps
transformations lazy and returns terminal results directly. The direct functions
in `fp.combinators` re-export their canonical operations from `fp.iteration`
and, for conditional composition, `fp.algebra`.

The table uses `Pipeline` spellings. Select a family with `pipeline[Family](value)`
when it cannot be inferred; each following operation uses that selection.
For lazy signatures, see the [iteration reference](iteration.md).

| Method | Meaning |
|---|---|
| `.map(transform)` | Transform each payload |
| `.fill(value)` | Replace payloads with `value`; single-call families move it, repeated mappings copy it |
| `.replace(old, new)` | Replace equal payloads; keep unmatched values |
| `.void()` | Replace each payload with `NoneType`, preserving shape |
| `.tuple_left(value)` | Attach value on the left; move it once or copy for repeated mappings |
| `.tuple_right(value)` | Attach value on the right; move it once or copy for repeated mappings |
| `.pair_with(project)` | Produce `(element, project(element))` |
| `.tap_each(inspect)` | Inspect each element and retain it unchanged |
| `.tap(inspect)` | Inspect the whole `Pipeline` value, including ordinary structs |
| `.filter(predicate)` | Retain accepted payloads |
| `.filter_not(predicate)` | Retain rejected payloads |
| `.filter_map(transform)` | Transform to `Optional` and retain present results |
| `.compact()` | Unwrap present `Optional` payloads and discard absent ones |
| `.find_map(transform)` | Return the first present transformed result |
| `.fold_left(step, initial)` | Fold in source order from an initial value |
| `.fold_map[Monoid](project)` | Project and combine in one pass |
| `.combine_all[Monoid]()` | Combine with the monoid's operation and identity |
| `.sum()` | Add in order from zero |
| `.sum_by(project)` | Project and add without an intermediate collection |
| `.min_by(project)` | Return the element with the smallest key |
| `.max_by(project)` | Return the element with the largest key |
| `.flat_map(transform)` | Transform and flatten according to the container's semantics |
| `.flatten()` | Remove one nesting level |
| `.flat_tap(inspect)` | Sequence an effect on a borrowed payload; retain the original per successful branch |
| `.flat_pair_with(project)` | Sequence an effect on a borrowed payload; emit `(original, projected)` per successful branch |
| `.followed_by(make_next)` | Sequence a zero-argument factory and keep its produced values |
| `.before(make_next)` | Sequence a zero-argument factory; retain the original per successful branch |
| `.map2(other, combine)` | Combine two already constructed operands in their Applicative family |
| `.product(other)` | Combine them into tuples |
| `.product_r(other)` | Sequence both already constructed effects and keep the right payload |
| `.product_l(other)` | Sequence both already constructed effects and keep the left payload |
| `.ap(values)` | Apply callbacks stored in this carrier to another carrier's values |
| `.traverse(transform)` | Collect effectful results inside the target effect |
| `.traverse_void(transform)` | Run effects and discard successful payloads without collecting them |
| `.traverse_tap(inspect)` | Run effects on borrowed payloads and retain the original values on success |
| `.sequence()` | Turn a container of effects into an effect of a container |
| `.sequence_void()` | Sequence existing effects and discard successful payloads |
| `.flat_traverse(transform)` | Traverse effects and flatten one source-container level inside the effect |
| `.flat_sequence()` | Sequence existing effects and flatten one source-container level |
| `.traverse_filter(transform)` | Traverse effects containing Optional payloads and retain present results |
| `.filter_effect(predicate)` | Retain originals accepted by a borrowing, effectful Bool predicate |
| `.fold_effect(initial).run(step)` | Pass the accumulator and next element to an effectful step |
| `.any_effect(predicate)` | Test until an effectful predicate succeeds with `True` |
| `.all_effect(predicate)` | Test until an effectful predicate succeeds with `False` |
| `.recover(handler)` | Replace the selected stored error with a success value |
| `.or_else(handler)` | Replace the selected stored error with another effect |
| `.if_effect(on_true, on_false)` | Select a zero-argument effect factory from an effectful Bool |

For direct calls, put the source last: `fill(value, source^)`,
`replace(old, new, source^)`, `sum_by(project, source^)` or
`fold_map[Monoid](project, source^)`. Operations without a runtime argument take
only the source, such as `compact(source^)` and `sum(source^)`. `tap` is a
whole-value `Pipeline` method. Direct traversal, like `Iter.traverse`, gathers a
`List` inside the chosen effect.

## Recover a selected error layer

`pipeline[Family](value^).recover(handler)` consumes a stored error and replaces
it with a success value. `.or_else(handler)` continues with the handler's effect.
Canonical Result pipelines can change the stored-error type through `or_else`;
other error-capable families retain their selected error layer. Success skips
the handler, and a failure returned by the handler passes onward without calling
it again. See [selected recovery](functions.md#select-family-and-native-errors-before-callbacks)
for the public generic contracts.

`ResultFamily[E]`, `ValidationFamily[S]` and `ResultT[Base, E]` support these
methods through `ApplicativeError`. Construct a stored failure with
`fail[Family, A](error)` from `fp.algebra`; `A` supplies the missing success type.
A list of Results selects `ResultT[ListFamily, E]` to recover its failed entries.
ReaderT, WriterT, OptionalT and StateT lift the same methods from an error-capable
base Monad. StateT recovery requires copyable state.

Use `.recover_if(predicate, handler)` or
`.or_else_if(predicate, handler)` to handle only matching errors.
The predicate borrows the selected error and returns Bool. A match transfers
that error to the handler; a non-match preserves it through the family's
`fail`. Success skips both callbacks. The same methods work with Validation,
ResultT and the lifted transformers, with their usual timing and branching.

Use `.tap_err(inspect)` to borrow the selected error for inspection
and retain it. The observer's return value is discarded, even if it is a
stored failure. `.flat_tap_err(inspect)` instead sequences the
observer's returned effect before the original failure. Observer success
restores the original error; observer failure follows the family's combination
policy. Result keeps the observer error, and Validation accumulates observer
errors followed by the original errors. An empty observer effect, such as an
empty List or Optional absence, remains empty. Both methods skip source success.

Observers borrow errors; native callbacks stay borrowed until execution and
owned library callbacks move into the computation. Branching requires a
repeatable observer and may require copyable stored errors when retaining them
across observer branches. Success payloads need not be copyable. Native raised
errors propagate, including failure-constructor and Validation semigroup
errors. `flat_tap_err` follows the selected family's timing, state and log rules.

<!-- example: docs/examples/error_recovery.mojo -->

The selected family determines which error to handle. With
`ResultT[ResultFamily[Outer], Inner]`, recovery handles the inner error and
passes outer failures through, even when both error types are identical.
Validation recovers its stored accumulated error as one value and remains an
Applicative without Monad bind. Existing inferred Result methods retain their
contracts, including `.or_else(handler)` changing the error type.

ResultT follows its base's timing and branching. A List base handles each
failed entry in input order; its handler may return zero, one or several
entries. Reader and State bases defer recovery until `run`. State updates and
Writer logs below ResultT stay in place. Native raised errors propagate with
their exact types; these methods do not turn exceptions into stored errors.

ReaderT recovery uses the same borrowed environment, including when a nested
base retains it until a later run. OptionalT leaves absence unchanged. A failed
WriterT base contains no log, so recovery returns the handler's log; `.recover`
introduces the monoid's empty log through `pure`.

StateT recovery saves the state at the recovery boundary and runs the source
on a copy. Each handler starts from that saved input. Copyable does not imply
a deep snapshot, and external mutation is not rolled back. ResultT above State
keeps the updated state instead and does not require copying it.

<!-- example: docs/examples/transformer_recovery.mojo -->

`product_r` sequences an already constructed failure recipe after the state
update. StateT's declared recipe identifies its family; `pipeline[Keep]` selects
the erased ResultT layer explicitly. Extracting that chain with `.get()` leaves
a State recipe for `run[State[Int]]`. The final `tupled(show_kept)` passes both
tuple elements by move to a normal two-argument function.

Native handlers are borrowed in place. Owned library handlers move into the
computation; single-use paths admit consuming handlers and move-only values.
A branching base requires a repeatable handler. Deferred computations retain
callback borrows until execution, so keep those callbacks alive and unmoved.
For new generic wrappers, forward the public contracts in the
[generic-wrapper guide](../guides/generic-wrappers.md).

The compatibility `Piped` methods retain per-method `[Family]` selection.
Their native forwarding may supply the complete callback result and raised
error as `.or_else[Family, R=R, X=E](handler)` or
`.recover[Family, R=R, X=E](handler)`. Conditional methods use `R` for the
handler result, `X` for the predicate's native error, `E` for the handler's
native error and `Z` for an explicit common construction error when generic
forwarding needs it. Native raises from a non-match's `fail` also propagate;
Reader and State may defer that construction until `run`.

Compatibility `Piped` observers accept `R` for the complete native callback result,
`X` for its native error and `Z` for an explicit common construction error.
Inferred Result `flat_tap_err` accepts `U` for the observer's success payload,
with its return structurally fixed to `Result[U, E]` to retain error origins.

## Validate and observe outcomes

Select an error-capable family once with `pipeline[Family](source^)`, then use
`ensure`, `redeem`, `redeem_with` and `attempt_tap` without repeating the family.
The compatibility Piped forms below select the family on each operation and
keep that family's stored-error type.

| Method | Callback contract | Required capability |
|---|---|---|
| `ensure[Family](predicate, make_error)` | Borrow a success for a Bool test; borrow it again to construct an error only on rejection | Monad and ApplicativeError |
| `redeem[Family](on_ok, on_err)` | Consume the original success or error; both handlers return the same success type | ApplicativeError |
| `redeem_with[Family](on_ok, on_err)` | Consume the original success or error; both handlers return the selected family with a common success type | Monad and ApplicativeError |
| `attempt_tap[Family](inspect)` | Borrow the whole `Result[A, E]` representing the selected outcome; return an effect in the same family | Monad and ApplicativeError |

An existing failure skips both `ensure` callbacks. Rejection invokes the
family's failure constructor, whose native exceptions propagate unchanged.
The two-branch methods select a handler from the original outcome only: a
stored failure returned by `on_ok` does not invoke `on_err` in that operation.
Whole-outcome observation restores the original success or failure after an
observer success. An observer failure replaces it, and an empty observer effect
stays empty. Native raised errors remain separate from stored outcomes.

<!-- example: docs/examples/shared_outcomes.mojo -->

The example finishes by selecting the outer List and calling `sequence()`.
This consumes a List of Results into a Result containing a List; `raise_on_err()`
then returns the rendered strings or raises the stored error. Both operations
move payloads. When outcomes remain mixed, use `fold_owned` to format each
selected branch, as in the recovery example, or borrowing `fold` to inspect it.

ResultFamily and ResultT support all four methods. ReaderT, StateT, WriterT
and OptionalT inherit support from an appropriate base. Validation supports
`redeem`; it has no Monad bind and does not support the other shared forms.
An absent Optional and an empty List produce no outcome to observe. With nested
error layers, only the selected layer becomes the observer's Result; failures
outside it still bypass the callbacks.

Native callbacks stay borrowed through deferred execution. Owned library
callbacks move into the computation, including their skipped captures.
Branching requires repeatable callbacks. `attempt_tap` also needs copyable
retained outcomes when an observer can branch; its discarded success payloads
can be move-only. Single-use paths add no Copyable requirement.

State, logs and timing follow the existing recovery and bind rules described
above. Restoring an observed failure invokes `fail[A]`, including any native
construction error. An observer failure skips that restoration. Native errors
from callbacks and family operations must have one common exact type, or be
non-raising; the library does not erase error origins or convert exceptions.

Generic forwarding uses complete callback result types `R` and `S`, native
callback errors `X` and `Y`, and optionally `Z` for the exact common construction
error. `attempt_tap` uses only `R` and `X`. Follow the existing complete-carrier
convention when a native generic handler returns a Result: name that whole
result type and constrain it to the selected family's error type.

## Sequence dependent effects

`flat_tap`, `flat_pair_with`, `followed_by` and `before` chain directly on Piped and Iter.
Piped infers List, Optional and Result; select another Monad explicitly,
as in `.before[Reader[Config]](make_next)`. Each callback returns a value in
the same family as its source. Iter callbacks return native iterables or
iterators, which are flattened lazily.

`flat_tap` borrows each payload for its callback. `before` and `followed_by`
call a zero-argument factory once per source success. An empty source, absent
Optional or stored Result error skips that callback. `flat_tap` and `before`
retain the original once for each success produced by the callback: two List
elements produce two copies of the original, and an empty List produces none.
The factory's values become the output of `followed_by`.

`flat_pair_with` borrows the original for an effectful projection and pairs it
with each successful projected value. A projection returning `[11, 21]` for
input `1` produces `[(1, 11), (1, 21)]`; an empty projection produces no pair.
The family preserves absence and stored errors, and an absent or failed source
skips the projection. Each pair has two fields, even when the original is
itself a tuple.

<!-- example: docs/examples/monad_sequencing.mojo -->

List and iterator retention requires `Copyable` originals, even when a
particular callback happens to yield one element. Optional and Result move
their retained payloads and allow consuming callbacks. `followed_by` allows
move-only originals in every family because it discards them. Multi-element
sources require repeatable callbacks; supplied library callbacks are consumed.
`flat_pair_with` moves each projected value into its pair, so projections can
be move-only even when a branching source requires copyable originals.
Projection results may retain external origins, but cannot borrow an original
that moves into the output.

Piped's native List, Optional and Result methods execute immediately. Reader
and State preserve deferred execution, and Iter pulls nothing until advanced.
Native callbacks passed to Piped are borrowed until the computation finishes;
keep them alive and unmoved. Lazy Iter owns its callbacks, including mutable
captured state, and resumes the source's current position. Abandoning it drops
remaining state without running further callbacks.

Native raised errors retain their exact types and remain distinct from stored
Result errors. Iter callbacks cannot raise. `before` retains the original only
when the next effect succeeds; it is not an unconditional cleanup operation.
The existing direct Result methods follow these same sequencing rules.

## Result composition

These methods are available directly on `Result` and on `piped(result^)`.
They execute immediately and consume the Result. Native callbacks are borrowed
in place; library callbacks are consumed, including callbacks skipped on the
inactive branch.

| Method | Selected branch and callback | Output |
|---|---|---|
| `flat_tap(project)` | Borrow `Ok`'s payload; return a Result with the same error type | Original success, or the projection's error |
| `flat_pair_with(project)` | As above | Tuple of original and projected successes, or the projection's error |
| `followed_by(make_next)` | On `Ok`, call a zero-argument Result factory | Factory's Result |
| `before(make_next)` | As above | Original success, or the factory's error |
| `ensure(predicate, make_error)` | Borrow the success for the predicate; call the borrowing error factory only on rejection | Original success or the constructed error |
| `recover(function)` | Consume `Err`'s payload and return a success value | `Result[T, E]`, preserving the declared error type |
| `tap_err(inspect)` | Borrow `Err`'s payload; discard the inspector's return value | Original Result |
| `recover_if(predicate, function)` | Borrow the error for the predicate; consume it in the recovery only on `True` | Recovered success or original Result; keeps `Result[T, E]` |
| `or_else_if(predicate, function)` | As above, with a recovery returning `Result[T, E]` | Recovery's Result or original Result |
| `flat_tap_err(inspect)` | Borrow the error; return `Result[U, E]` | Original error on observer success, observer error on failure; `Ok` unchanged |
| `map_both(on_ok, on_err)` | Consume the selected payload; map success to `U` or error to `V` | `Result[U, V]`, preserving the selected constructor |
| `redeem(on_ok, on_err)` | Consume the selected payload; either handler returns `U` | `Ok(U)` in `Result[U, E]` |
| `redeem_with(on_ok, on_err)` | Consume the selected payload; either handler returns the same `Result[U, V]` | Selected handler's Result |
| `attempt_tap(inspect)` | Borrow the whole `Result[T, E]` once; return `Result[U, E]` | Original outcome on observer success, observer's `Err` on failure |
| `map2(other, combine)` | Consume two `Ok` payloads and combine them | Combined success, or the first stored error |
| `product(other)` | As above, without a callback | Tuple of successes, or the first stored error |
| `ap(values)` | On two successes, consume the stored callback and its argument | Callback's result, or the first stored error |
| `if_effect(on_true, on_false)` | On `Ok[Bool]`, invoke the selected zero-argument Result factory | Selected Result, or the condition's stored error |

`flat_tap` incorporates the callback's Result, including a possible failure;
`tap_each` discards a callback's returned value. None of the Result combinators
copies the original payload or requires `Copyable`. Results, captured values,
and raised errors keep their native origins. Native `raises` errors propagate;
these methods handle only stored errors. Operations taking two callbacks require
one common native error type, or one callback must be non-raising. Each selected
callback runs at most once; a rejected recovery
predicate keeps the original error and skips the recovery.

`or_else_if` keeps the stored error type because unmatched errors must remain
representable. `flat_tap_err` incorporates its observer's failure; `tap_err`
discards the observer's return value, even when that value is a Result.

Two-branch methods use `(on_ok, on_err)`, matching `fold_owned`. Only the
original branch selects a handler: an `Err` returned by `redeem_with`'s success
handler does not run its error handler. `redeem` keeps the Result wrapper;
`fold_owned` returns the selected value directly. `attempt_tap` observes stored
outcomes, and does not catch native raised errors.

`map_err` and `or_else` also forward through Piped, including changes to the
stored error type. See [Results and recovery](../tutorial/results.md#compose-validation-and-recovery)
for a complete chain and generic forwarding conventions.

## Containers and capabilities

| `Piped` operations | Automatic native support | Explicit family capability |
|---|---|---|
| `map`, `fill`, `replace`, `void`, tuple methods, `pair_with`, `tap_each` | List, Array, Deque, LinkedList, Dict, StringDict, Optional, Result | Functor |
| `filter`, `filter_not` | List, Deque, LinkedList, Dict, StringDict, Optional | Filterable |
| `filter_map`, `compact` | List, Deque, LinkedList, Dict, StringDict, Optional | FunctorFilter |
| `flat_map`, `flatten` | List, Optional, Result | Monad |
| `map2`, `product`, `ap`, `map_n`, `product_n` | List, Optional, Result | Applicative |
| `flat_tap`, `flat_pair_with`, `followed_by`, `before` | List, Optional, Result | Monad; also lazy Iter methods |
| `recover`, `or_else`, `recover_if`, `or_else_if`, `tap_err`, `flat_tap_err` | Result | ApplicativeError |
| `redeem` | Result | ApplicativeError |
| `ensure`, `redeem_with`, `attempt_tap` | Result | Monad and ApplicativeError |
| `map_both`, `map_err` | Result | Result methods; no generic family overload |
| `traverse`, `sequence`, `traverse_tap` | List, Optional, Result | Traversable source and Applicative target |
| `traverse_void`, `sequence_void` | List, Array, Deque, LinkedList, Optional, Result | Applicative target; use `Iter` for other owned iterable sources |
| `flat_traverse`, `flat_sequence` | List, Optional, Result | Traversable and Monad source; Applicative target |
| `traverse_filter`, `filter_effect` | List, Optional | Traversable and FunctorFilter source; Applicative target |
| New reductions and searches | List, Array, Deque, LinkedList, Dict, StringDict, Optional | Use an owned iterator with `Iter` for other sources |
| `fold_effect`, `any_effect`, `all_effect` | Native owned iterable sources and iterators; Array uses temporary List storage | Monad target |
| `if_effect` | List, Optional, Result containing Bool | Monad |

Container operations preserve native shape and settings. Dictionaries operate
on **values**, retaining keys, insertion order and hasher for transformations;
reductions consume values too. Deques retain bounds and storage policy. Arrays
retain length for mapping; they cannot filter while retaining their type.
Result has no implicit rejection policy or terminal that discards its error.
`Piped.fold_left` and the three effectful reductions follow native iteration,
including dictionary keys. Result is a target effect for these reductions;
it is not an iterable source.

For a custom container, select its capability explicitly:
`piped(tensor^).fill[TensorFamily](0)` or
`piped(source^).filter_map[SourceFamily](transform)`. The family determines
result types, evaluation and errors. A custom Functor needs only `map` for the
mapping conveniences; a FunctorFilter needs only its `filter_map` primitive
for `compact`. No per-combinator container implementation is needed.

Custom traversal names both families:
`.traverse[SourceFamily, EffectFamily](transform)` and
`.sequence[SourceFamily, EffectFamily]()`. The native List, Optional and Result
forms infer the source family. Generic callback forwarding can select a family,
as in `.pair_with[ListFamily](project)`, or name inferred callback parameters,
as in `.sum_by[A=T, R=Int, E=E](project)` for a generic raising function.

`traverse_tap` uses the same source selection as `traverse`. A generic raising
wrapper can use `.traverse_tap[ListFamily, OptionalFamily, E=E, X=E](inspect)`.
`X` supplies exact error evidence when Mojo cannot reduce a generic family
error expression; it must match the actual error and never converts or erases
it. Generic Result-source `traverse_void` can use all-keyword parameters
`G=OptionalFamily, A=A, R=R, Failure=S, E=E, X=E`, where `R` names the complete
callback result type, such as `Optional[Int]`.
The new traversal methods use the same explicit source/target order and `E`/`X`
error evidence. For example, `.flat_traverse[ListFamily, OptionalFamily, E=E, X=E](transform)`
forwards a generic raising callback. `flat_traverse` requires the callback's
successful payload to belong to the same source family; Result's stored error
type, including its origins, must agree at both levels.
For fluent binary callbacks, the native parameter names are `A`, `B`, `R` and
`X`: a generic Piped wrapper can supply
`.map2[A=A, B=B, R=R, X=X](other^, combine)` as evidence for its native shape.

Use `iterated(source)` for a range, borrowed iterator or custom iterator.
Its elements follow native iteration: iterating a dictionary yields keys.
Its `traverse(callback)` and `traverse_void(callback)` infer a recognized target
from the callback result, just as Pipeline does. Explicit target and callback
bindings retain their order; see [iterator traversal](iteration.md#traverse-into-an-effect).
Iterator sources continue at their current position, and adapters fuse
exhaustion. Abandoning a lazy chain destroys its owned state without calling
remaining transformations.

## Evaluation, ownership and errors

Built-in `Piped` operations execute when their method is called. `.get()` only
extracts the result. `Iter` transformations, including `void` and `tap_each`,
execute as elements are pulled. `void` does not drain an iterator. Terminals
consume immediately; traversal runs according to its target effect, which may
itself be deferred.

`map2` and `product` consume two already evaluated operands. List combination
is Cartesian in left-major order and requires copyable payloads; `map2` also
requires a repeatable callback. Optional and Result combine at most once,
support move-only payloads and admit consuming callbacks. Result retains the
left error if both operands failed. A right operand's construction has already
happened even when the left operand failed; use `map2_lazy` with a factory when
construction must be skipped.

`traverse_void` uses the target family's existing accumulation loop with a
`NoneType` accumulator, so it creates no output collection. It consumes source
elements and requires a repeatable callback, including for an Optional source.
Empty input succeeds with `None` in the target effect. A branching effect can
produce several successful `None` values. Short-circuiting targets stop further
source pulls and callbacks after failure. Array still needs the input buffer
described below. Piped dictionaries do not yet have this method.

For a Result source, `traverse_void` instead returns the target effect of
`Result[NoneType, E]`: a source `Err` is preserved and skips the callback, while
a source `Ok` sequences the callback and discards its successful payload. This
path admits consuming callbacks and move-only errors. Like existing `traverse`,
Optional and Result source traversal requires a target that can represent the
inactive and active source branches with the same carrier type.

`traverse_tap` borrows each element for its effectful callback. When that effect
succeeds, the original element moves into the result; failed branches release
it. Piped preserves the source family's shape, including an existing Result
error inside the target effect. Iter and direct calls collect originals in a
List. Branching targets need copyable originals; single-output targets support
move-only originals. Optional and Result sources can use a consuming borrowing
callback. Both traversal conveniences preserve the target effect's timing:
Reader and State defer traversal until run. Native callbacks remain borrowed
until the returned computation completes; keep them alive and unmoved.

`sequence_void` is `traverse_void` with an identity callback. It consumes
already constructed effects, so stopping traversal cannot undo their construction.
A Piped Result source keeps its stored error inside `Result[NoneType, E]` in
the target effect, just as `traverse_void` does.

`flat_traverse` traverses a callback returning an effect of another source
container, then flattens one source level inside the effect. A List source
with an `Optional[List[U]]` callback produces `Optional[List[U]]`.
`flat_sequence` performs the same operation on existing effects. A source Result
error stays inside the target effect; target failures remain outside it.

`traverse_filter` takes an owned element into a callback returning an effect of
`Optional[U]`. Present results become output elements; absent results remove
only that element. `filter_effect` takes a borrowing predicate returning an effect of
`Bool`: successful `True` retains the original and `False` removes it. Neither
absence nor `False` stops traversal. Target failure does stop a short-circuiting
effect. These operations support List and Optional sources automatically and
custom Traversable/FunctorFilter sources explicitly. Result has no implicit
filtering policy. Fixed-size containers cannot preserve their shape when an
element is rejected.

These operations share traversal's callback and target semantics. Native
callbacks are borrowed in place; library callbacks are consumed. Multi-element
sources require repeatable callbacks. Single-output effects support move-only
payloads; branching effects require copyable retained values and accumulators.
Iter and direct calls collect a List inside the effect and are traversal
terminals. Reader and State defer both traversal and its final transformation.
Native raised errors propagate unchanged, including errors added by a custom
source family's flattening or compaction.

Flattening and compaction run after traversal succeeds. List sources therefore
use an intermediate nested or Optional collection and a second pass, with
linear work in the traversed and emitted elements per successful branch.
`sequence_void` uses the discard accumulator and creates no output collection.

`fill` moves its replacement for a single invocation, including Optional,
Result and Identity mappings. These accept move-only replacements. Compared
with the earlier copying behavior, successful single-call fills now also avoid
an extra copy for Copyable replacements. Repeated collections and lazy iterator
fills require `Copyable` and make one copy per emitted payload; the requirement
also applies to an empty collection. Deferred effects follow their existing
map receiver policy and retain the replacement until execution or disposal.
Empty inputs remain empty, and stored errors pass through. Both still consume
and destroy unused replacements.

`tuple_left` and `tuple_right` use the same receiver policy for attached values.
Single-call families accept move-only attachments and avoid the former extra
copy even when the attachment is Copyable. Empty or failed carriers dispose of
unused attachments. Collections, lazy Iter methods and free iterator functions
require Copyable and make one copy per emitted pair; an empty source keeps that
requirement. The original payload is moved into the other tuple position, and
both positions keep their origins. Deferred families retain attachments until
execution or disposal.
`replace` compares whole payloads, requires
the same element type for `old` and `new`, copies `new` only on matches, and
moves unmatched elements unchanged. It does not perform substring replacement.

`pair_with`, `tap_each`, `min_by` and `max_by` borrow each element for the
callback. `pair_with` then moves the original beside its projection; inspection
moves the original onward unchanged and discards the callback's return value.
These operations support move-only elements. Projection results retain their
native origins; the API cannot return a view into a moved, locally owned element.
`filter_map`, `find_map`, `fold_map` and `sum_by` move elements into their
transformations instead.

Eager and terminal native callbacks are borrowed in place. Lazy native callbacks
are owned by the iterator, including their captured state. Library callback
arguments are consumed. Repeated transformations require repeatable callbacks;
Optional and Result retain their existing one-shot mapping/binding support.
Native errors keep their exact type. A callback error, even `StopIteration`,
is distinct from source exhaustion. Lazy iterator callbacks cannot raise domain
errors; use effect-bearing elements and traversal when needed.

`find_map` returns an absent `Optional` if nothing matches and pulls nothing
after its first present result. `min_by` and `max_by` also return `Optional`,
compute each key once, and keep the first element on ties. Monoidal reductions
return the identity on empty input. Callback and monoid errors must be the same
native type, or `Never`; unrelated errors require an explicit mapping.

`sum` and `sum_by` support native `Int` and numeric `SIMD`, including scalar
aliases such as `Float64`. They preserve the numeric type, add sequentially
from zero, and keep SIMD lanes separate. Custom numeric types can use
`fold_map` or `combine_all` with a Monoid.

Array mapping and terminals use a temporary List to preserve ownership with
the Mojo 1.1 owning-iterator limitation. This costs O(N) temporary
storage; Array searches buffer the input before searching. Other new
reductions do not construct an intermediate mapped container. See the
[architecture chapter](../architecture/functions.md#derived-combinators) for
the shared implementations and the
[iteration reference](iteration.md) for native source contracts.

## Combine and inspect effects

Use `.map_n((second, third), combine)` to combine three effectful values without
an intermediate lambda. The receiver supplies the first argument to `combine`.
`.product_n((second, third))` produces a flat `Tuple[A, B, C]` in the same
family. Start with `pipeline(value)` for native carriers or declared effect
recipes, or `pipeline[Family](value)` for another Applicative or an erased layer.
The following operations retain that selection. Compatibility Piped calls keep
per-method `.map_n[Family]` and `.product_n[Family]` selections.

Operands are consumed and already constructed. Combination follows receiver-first
order, with the last operand varying fastest in List's Cartesian product.
Result retains the first stored error; an absent Optional or a failed Result
skips the combiner. Optional and Result move their payloads, including move-only
values. Branching families retain their existing copying requirements. Native
raised errors remain native, and all payload and stored-error origins must agree
exactly. Reader and State defer execution until `run` and preserve their order.

Native functions and closures take one argument per operand, from one to eight.
They are borrowed until the family finishes using them. Library `Unary`,
`MutableUnary` and `OnceUnary` callbacks instead receive the whole flat tuple;
the family selects the supported receiver mode. Pipeline products and library
callbacks use variadic operand packs; native callback overloads cover one to
eight operands. An empty additional tuple produces a one-element product;
`.map_n((), native_function)` behaves as unary mapping.

Combination builds successive tuple prefixes through `map2_lazy`, then `map_n`
maps its callback over the final product. List therefore allocates intermediate
Cartesian collections and visits the final collection again for mapping; the
number of final combinations is the product of the input lengths. Optional
and Result add stack tuple/optional storage, without a collection allocation.
Use `map2` for binary combination when the extra tuple pass is unnecessary.


Use `functions.ap(values)` when the callback is itself inside an effect.
A Pipeline infers native carriers or uses the family selected at its start.
The receiver contains library unary callbacks; promote a native function or closure with
`as_unary` before storing it. Unlike a callback passed to `map2`, this callback
is an owned payload of its carrier.

Both operands are consumed and already constructed when the method is called.
Optional and Result invoke a successful callback at most once, admitting
move-only arguments and once-only callbacks. Absence or failure skips the
callback; Result preserves the first stored error in receiver-first order.
List copies each callback and value into every Cartesian pair, with functions
as the outer loop. A mutable callback's copied state belongs to that pair.
Empty Lists produce no outputs. Reader and State retain their existing deferred
execution and sequencing order. Native errors and borrowed origins are preserved.
The operation adds no collection beyond the carrier produced by combination.

The callback below returns a transformed number, but `traverse_tap` keeps the
input numbers. Its Result target is inferred from `check`. Finish a Result
pipeline with `.raise_on_err()` to extract success and propagate a stored error.
The iterator's `traverse_void(check)` infers Result from the callback and checks
the whole iterator without collecting those numbers.

<!-- example: docs/examples/fluent_effects.mojo -->

<!-- api: combinators -->


## Flatten and filter effects

`filter_effect` checks effectful Bool decisions, while `traverse_filter` lets the
callback change the payload type as it selects values. In this example, a
successful `False` is a filtering decision; `sequence_void` discards it as a
successful effect payload.

<!-- example: docs/examples/traversal_composition.mojo -->

## Fold and choose effects

`fold_effect` consumes an accumulator and each source element in order. Its
step returns an effect containing the next accumulator of the same type.
An empty source returns `EffectFamily.pure(initial)`. `any_effect` and
`all_effect` borrow each element for a predicate returning an effect of Bool.
They return `False` and `True`, respectively, on empty input.

<!-- example: docs/examples/effectful_reductions.mojo -->

The fold sums `3`, `5` and `8` to `16`. The second chain tests for a large
value, then invokes `large` because the effect contains `True`. The final
fold stops when `checked_add` returns `Err` for `-1`; it never processes `8`.
No callback runs after a Result failure or Optional absence, and iterator
sources receive no further pulls. `any_effect` stops at `True`; `all_effect`
stops at `False`. A native error propagates unchanged and also stops the work.

Piped wraps the resulting effect for further chaining; Iter returns it
directly. Direct calls put the source last:
`fold_effect[EffectFamily](step, initial^, source^)` and
`any_effect[EffectFamily](predicate, source^)`. Both pipeline forms run eager
effects immediately. A Reader or State target stores the source and callbacks
until `run`; keep borrowed native callbacks alive and unmoved until then.
The source iterator is consumed at its current position.

`if_effect(on_true, on_false)` consumes an effect of Bool and calls only its
selected zero-argument factory. It skips both factories for a failed Result or
absent Optional. The branches return effects from the same family with the
same successful payload type; Result also keeps the exact stored error type.
Piped infers List, Optional and Result, or accepts an explicit Monad family.
The free form is `if_effect[EffectFamily](on_true, on_false, condition^)`.
Library factories are consumed even when skipped; native factories are
borrowed. Optional and Result accept once-only factories with move-only
captures. A branching effect such as List needs repeatable factories.

List reductions visit each live accumulator in order for each source element.
They copy that element for each branch, so List targets require copyable
elements. Finished predicate branches are retained once: they are neither
tested again nor expanded by later decisions. The source stops when no live
branches remain. Non-branching targets move inputs and support move-only
elements and accumulators. All fold steps must be repeatable; a mutable
library binary callback can retain its own state between calls.

These reductions add no mapped source collection and use constant stack depth.
They retain the target's accumulator carrier and one element at a time;
branching targets may allocate and grow their outputs. Piped Array sources
first move into O(N) temporary List storage, including when a predicate stops
early. Custom eager Monad families with a stable carrier inherit the shared
driver; deferred families supply the fold hooks described in the
[architecture](../architecture/algebra.md#dependent-folds-and-conditions).

For generic native forwarding, retain the signature's parameter names and
provide the payload equality as evidence. A binary fold uses `A`, `B`, `R`
and native error `X`, with `Z=X` for its construction error. Predicates use
`P`, `R`, native error `E` and `X=E`. Conditional factories use `U`/`Y` on
the true branch and `W`/`D` on the false branch, with `X` for the common
construction error. For example, a generic Optional fold needs both
`R == Optional[A]` and `OptionalFamily.Element[R] == A`; Mojo 1.1 does not
derive the second equality from the first. These error parameters supply
exact type evidence and cannot convert errors or relabel their origins.


## Accumulate independent validation errors

Use `par_map_n` when independent Results should report all stored failures.
The receiver is the first operand, followed by a tuple of additional operands;
the constructor callback runs once only when every operand is `Ok`.
Use `par_product_n` to keep the successful payloads in a flat tuple without a
constructor callback. `par_traverse` applies a validator to every element of a
finite source, keeping all stored errors in source order. `par_sequence`
collects Results already in a source. Native raised errors stop these operations
immediately and keep their exact type.

| Method | Available on | Successful result |
|---|---|---|
| `.par_map_n((second, third), construct)` | Piped holding Result | The constructor's output |
| `.par_product_n((second, third))` | Piped holding Result | A flat tuple, receiver first |
| `.par_traverse(validate)` | Piped holding List, Optional or Result; Iter | Transformed payloads in source shape; List for Iter |
| `.par_sequence()` | Piped holding List, Optional or Result; Iter | Unwrapped payloads in source shape; List for Iter |

<!-- example: docs/examples/parallel_validation.mojo -->

The first combination produces `total: 9`. The second reports both invalid
inputs, `-2` and `-4`. Traversal reports `-3` and `-5` together, and the
iterator produces the squared values `1`, `4` and `9`. A shared Kleisli chain
passes directly to either pipeline form. The product keeps `(2, 3)`; sequencing
reports both failures from the list of completed checks.

The default error type is `List[E]`, concatenated using `ListMonoid[E]`.
These methods preserve that type: validators return
`Result[A, List[E]]` themselves. An `Err` with an empty list stays an `Err`.
For another error type, choose an explicit associative policy:
`.par_map_n[ErrorCombiner]((second, third), construct)` or
`.par_traverse[ErrorCombiner](validate)`. The conveniences accept the same policy:
`.par_product_n[ErrorCombiner]((second, third))` and
`.par_sequence[ErrorCombiner]()`. A policy implements `Semigroup`,
with `Value`, optional native `Error`, and consuming `combine(left, right)`;
it needs no `empty`. `StringMonoid`, for example, concatenates scalar String
errors when selected explicitly. Multiple inhabited native error types must
agree; neither callback nor combiner errors become stored validation errors.

Piped supports List, Optional and Result traversal sources, preserving their
shape inside the output Result. Iter consumes from its current position and
collects a List. An empty source succeeds without calling the validator. A
Result source's stored `Err` remains inside the target effect as `Ok(Err(...))`;
it is separate from errors produced by the validator. Piped wraps the result
for further chaining; Iter returns it directly.

These methods execute immediately. `par_` selects error accumulation and does
not start threads. N-ary operands have already been evaluated before the call;
use traversal to run validators over a source. List and iterator traversal
require repeatable callbacks. Optional and Result sources also accept consuming
callbacks, because they invoke at most once. N-ary combination accepts consuming
tuple callbacks. Native
n-ary callbacks take one to eight arguments; library tuple callbacks and
`par_product_n` are variadic, including with an explicit error policy.
An empty additional-operands tuple maps the receiver alone, or wraps its
successful payload in a one-element tuple for `par_product_n`. That product
cannot raise even if its policy can: there is no pair of errors to combine.
Likewise, Optional and Result sequencing cannot invoke the policy combiner.
List and iterator sequencing can raise the policy's exact `Error` type.
Payloads,
errors and callback owners are moved without implicit copies. Native callbacks
and shared Kleisli chains are borrowed for the call.

For an explicit source family, use the existing
`traverse[SourceFamily, ValidationFamily[ErrorCombiner]]` operation. Custom
sources need only their existing Traversable implementation. `map_n`,
`traverse` with `ResultFamily`, and dependent `flat_map` keep their usual
short circuit behavior.
