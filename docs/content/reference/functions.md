# fp.functions

For a reusable generic wrapper, follow the [contract-forwarding guide](../guides/generic-wrappers.md).

`fp.functions` provides eager pipelines, function composition and partial
application. Use `pipe` to apply a sequence of functions now, `flow` or `compose`
to build a function for later calls, and `partial` to bind leading arguments.
The [pipeline tutorial](../tutorial/pipelines.md) starts with a complete program.

Use `.map(transform)` to preserve a supported native container and map its
payloads immediately. Use `.map[Family](transform)` for an explicit Functor
instance. `.filter(predicate)` and `.filter_not(predicate)` eagerly preserve supported
containers, and
`.fold_left(step, initial)` consumes an iterable immediately and keeps its
result in the chain. `.get()` extracts the stored value. See
[combinators](combinators.md) for supported containers and lazy alternatives.
`Piped` names its payload parameter `Value`: explicit `Piped[T=Int]` and
`Piped[Int].T` become `Piped[Value=Int]` and `Piped[Int].Value`.

## Select family and native errors before callbacks

`pipeline(values)` starts a `Pipeline` for List, Optional or Result. Other
values use Identity: `map` applies its callback to the whole bare value once.
`pipeline[Family](value)` selects another Functor explicitly, including a
deferred family. Call `raising[E]()` once to select native callback errors.
Existing explicit payload bindings, such as `pipeline[T=Int](values)`, remain
available. Generic wrappers over an unknown value type select a family
explicitly; use `pipeline[IdentityFamily](value)` for a whole-value stage.
For native sequences, `.elements()` infers the element family: for example,
`pipeline(array^).elements().map(transform)`. List, Array, Deque, LinkedList
and NonEmptyList are supported. Selection preserves the native error context
and performs no iteration or callback invocation.
`map`, `filter`, `flat_map` and `filter_map` use the selected family's
capabilities. Result combinators use their existing branch and ownership rules.
`map_err` and `map_both` use the selected family's `ErrorMapping` capability.
Result infers a new `ResultFamily` from the transformed stored-error type.

Stored thin native pointers can be passed directly to these selected operations,
including Result handlers and the existing `fold_left(step, initial)` and
`fold_until(step, initial)` forms. Deferred computations own the pointer value;
native closures retain their borrow origins. Generic native error parameters
may include `Never` without a separate non-Never constraint.

<!-- example: docs/examples/selected_pipeline.mojo -->

`raising[E]()` selects native callback admission. It does not change stored
errors, catch exceptions, or restrict the errors declared by library callables.
Pure and Never callbacks retain Never. Custom families retain their own
execution errors and deferred callback lifetimes. `get()` only extracts the
carrier.

`map_err(transform)` changes the selected stored error; `map_both(on_ok,
on_err)` maps the original branch once. Result calls infer their destination.
Validation retains its accumulation policy when the error type stays the same;
a changed error type requires an explicit destination such as
`map_err[Target=ValidationFamily[Messages]](format_errors)`. An explicit target
can also select a different accumulation policy over the same error type.
Subsequent fluent operations use that destination family. Mapping itself does
not combine errors or invoke the other callback after a native raise.

<!-- example: docs/examples/selected_error_mapping.mojo -->

`ResultT[M, E]` changes its selected inner error through one base map, preserving
callback order and leaving outer failures untouched. Its base need not support
`ErrorMapping`. `OptionalT[M]` maps the base's selected error when that Monad
supports `ErrorMapping`; an absent Optional stays absent. Deferred bases keep
mapping deferred.

<!-- example: docs/examples/selected_layer_error_mapping.mojo -->

`ReaderT`, `StateT` and `WriterT` also lift mapping from a base Monad with
`ErrorMapping`, independently of recovery. Reader retains the environment and
runs the callbacks later. State runs once with its owned state, without copying
or rolling it back; move-only state supports mapping without supporting
recovery. Writer retains the exact log and its monoid, including over a deferred
base. Each operation selects the destination family for fluent continuation.

<!-- example: docs/examples/selected_transport_error_mapping.mojo -->

A layer's proposed destination base must remain a Monad. OptionalT, ReaderT,
StateT and WriterT check the raw default candidate before wrapping it; an
unsupported default rejects normally. They can still accept an explicit
permitted Monad destination, such as `Target=OptionalT[ResultFamily[Int]]`.
Reader, State and Writer targets retain the exact environment, state type and
log monoid respectively. `ResultT` keeps its base policy and reselects
payload-dependent base metadata where needed.

`Pipeline` accepts `Target: Functor` and checks its `ErrorMapping` capability
before admission. Conditional aliases such as `OptionalT[...]` therefore work
as ordinary explicit targets without a cast. The public `MapBothContract` and
`MapErrContract` retain their `ErrorMapping` bounds. Generic wrappers over
conditional source or target families use `Functor` bounds, require
`conforms_to(I, ErrorMapping)` and `conforms_to(Target, ErrorMapping)`, and use
the same public `downcast` witnesses in the contract. Forward the full selected
family's capability; a proof about only its base does not replace that witness.

Custom families implement `ErrorMapping` to admit their own target policies and
exact construction errors. A custom `ApplicativeError` family without this
capability cannot use Result storage to bypass its policy. Intrinsic Result
calls under a family with neither error capability remain supported; generic
intrinsic wrappers must prove both `not conforms_to(I, ApplicativeError)` and
`not conforms_to(I, ErrorMapping)`. Existing positional callback bindings retain
their meaning; use the trailing `Target` binding by name when needed.

This fallback boundary also applies to `recover`, `or_else`, `tap_err`,
`flat_tap_err`, `recover_if`, `or_else_if`, `ensure`, `redeem`, `redeem_with` and
`attempt_tap`. An `ErrorMapping`-only family supports `map`, `map_err`,
`map_both` and `tap_err` when mapping back into itself is admitted. The other
operations require `ApplicativeError`, plus Monad where
specified below. Native Result storage never silently reselects `ResultFamily`
for a family missing that capability. To deliberately use the carrier's Result
semantics, extract it with `.get()` and pass it to `pipeline(...)`, or select
`pipeline[ResultFamily[E]](value)` explicitly.

Generic intrinsic Result wrappers must forward both negative capability
proofs for these operations too. Generic wrappers using public contracts keep
their existing `Compatible` proof; `OrElseContract`, `RedeemContract` and
`RedeemWithContract` report `False` for an unsupported mapping-only selection.

`recover(handler)` replaces a stored failure with a payload; `or_else(handler)`
replaces it with another effect. Both honor the selected `ApplicativeError`
family, including deferred transformers and custom families whose storage is a
native Result. Recovery preserves that family's construction errors, timing and
callback ownership, so the chain can continue with `.map(...)` immediately.
Deferred handler errors occur when the resulting computation runs.

Canonical Result pipelines also preserve their existing `or_else` behavior:
the replacement Result may change the stored-error type, selecting the matching
output `ResultFamily`. Intrinsic Result calls under a family with neither
`ApplicativeError` nor `ErrorMapping`, such as an explicit Identity selection,
retain this behavior. Other error-capable families retain their selected
stored-error layer.

Generic value-returning recovery can use `fp.algebra.RecoverContract` with an
`ApplicativeError` family. For selected `or_else`, use
`fp.functions.OrElseContract[I,V,H]`: its `Compatible` predicate and
`Family`/`Out`/`Error` projections describe both family recovery and Result's
type-changing case. This lets a generic wrapper retain fluent continuation
without importing a private adapter or assuming the result has native storage.
Its `Compatible` also requires an invocable handler and the selected family's
`OperationCompatible` proof. A rejected family operation is excluded before
its result metadata is needed; native Result storage never overrides that policy.

<!-- example: docs/examples/selected_recovery.mojo -->

`tap_err(observer)` borrows a selected stored error and discards the observer's
result, including a returned stored failure. For an `ApplicativeError` family,
the original error is reintroduced through its failure constructor, including
any native constructor error. A mapping-only family instead retains the original
error through its `ErrorMapping` primitive, explicitly targeting itself; it
never substitutes the default target family. `flat_tap_err(observer)`
instead sequences the observer's effect: successful branches retain the
original error, empty effects remain empty, and failed observers follow the
family's combination policy. Result keeps the observer error; Validation
accumulates it before the original error.

Both methods honor `ApplicativeError` families and preserve fluent continuation.
Success skips the observer. Native closures remain borrowed until execution;
stored thin pointers are owned, and library observers retain their receiver
mode. Deferred families keep observation deferred. Family construction errors
and native observer errors retain their exact types. See the algebra reference
for `TapErrContract` and `FlatTapErrContract` generic-wrapper metadata.

Plain observation also works for `StateT[ResultFamily[E], S]` with move-only
state, which cannot offer recovery with rollback. It neither copies the state
nor recovers from the failure; the source action keeps its usual state ownership.

<!-- example: docs/examples/selected_error_observation.mojo -->

<!-- example: docs/examples/mapping_error_observation.mojo -->

`recover_if(predicate, handler)` recovers matching stored errors with a value;
`or_else_if(predicate, handler)` uses a replacement effect in the same family.
The predicate borrows the error, and a matching handler consumes it. Unmatched
errors pass through the family's failure constructor. Success skips both
callbacks. These methods support `ApplicativeError` families, including
Validation and deferred transformers, and preserve the selected family for
subsequent fluent calls. Deferred callbacks execute when the action runs.

<!-- example: docs/examples/selected_conditional_recovery.mojo -->

`ensure(predicate, make_error)` validates each success through the selected
family. Both callbacks borrow the payload; the error factory runs only when
the predicate returns false. Existing failures skip both callbacks. The family
must provide `Monad` and `ApplicativeError`: this supports sequential Result
validation, custom families and deferred transformer stacks. Validation's
accumulating family has no Monad and does not admit this operation.

Validation, observation and conditional recovery can stay in one deferred
chain. Their callbacks run with the selected computation, and `.map(...)`
continues in the same family:

<!-- example: docs/examples/selected_validation_workflow.mojo -->

`redeem(on_ok, on_err)` turns the original selected success or stored failure
into a successful value. `redeem_with(on_ok, on_err)` continues with the chosen
handler's effect. Exactly one handler consumes each original outcome; a
returned stored failure or a native raise never invokes the opposite handler.
Family `redeem` needs `ApplicativeError`, including Validation; family
`redeem_with` also needs Monad. Deferred families keep the handlers deferred.

Custom error-capable families retain their error layer and execution policy,
even when their storage is native Result. Canonical and intrinsic Result
`redeem_with` calls preserve their existing ability to change the stored-error
type. Value `redeem` follows the family's payload-rebinding metadata, so a
subsequent `.map(...)` uses the correct selection.

For generic wrappers with library handlers, `fp.functions.RedeemContract[I,V,H,K]`
and `RedeemWithContract[I,V,H,K]` expose `Compatible`, `Family`, `Out` and
`Error`. Forward the combined predicate, or its `InputCompatible`,
`CarrierCompatible`, `OutputCompatible`, `NativeErrorsCompatible` and
`OperationCompatible` components. The last checks each map, recovery and bind
step used by the selected policy. Project the output family instead of assuming it equals the input.
`Error` describes construction; deferred actions retain their own run errors.
Existing family bodies still check representation and receiver requirements.
New wrappers can instead forward `InvocationCompatible`, which adds
`ReceiverCompatible` to the existing proof. Both handlers must supply a shared,
mutable or consuming receiver. This rejects missing receivers at the wrapper
boundary while preserving existing `Compatible` and expanded generic proofs.

<!-- example: docs/examples/selected_outcomes.mojo -->

`attempt_tap(observer)` borrows either original outcome as
`Result[Element, Failure]` and runs an observer effect in the selected family.
Successful observer branches restore the original outcome through that
family; observer failures replace it, and empty effects remain empty. This
requires `ApplicativeError` and Monad. Native Result storage under a custom
family does not bypass its construction or restoration policy. Deferred
observation stays deferred, and the chain retains the selected family.

<!-- example: docs/examples/selected_outcome_observation.mojo -->

`flat_tap(callback)` sequences a borrowing effect and keeps each original
payload. `flat_pair_with(callback)` pairs each original with every successful
projection. `before(factory)` sequences a zero-argument effect and keeps
originals; `followed_by(factory)` keeps the produced payloads. All four use the
selected Monad, including List, Optional, Result, custom families and deferred
stacks. Empty or failed carriers skip callbacks. Branching effects require
copyable retained originals; single-use effects move them. Construction raises
the family's exact `BindError`; deferred callback exceptions occur when run.

A Validation selection does not support Monad sequencing. Select
`pipeline[ResultFamily[ErrorType]](value)` for sequential Result behavior.
Legacy `piped` bindings remain available.

`filter`, `filter_not`, `filter_map` and `compact` continue in the output family
declared by the filtering capability. Defaults preserve custom families.
NonEmptyListFamily selects ListFamily because filtering can remove every
element, so a subsequent `.map(...)` works without selecting a family again.

`tap(observer)` borrows the whole value once, immediately, including an empty
container or Result's Err. `tap_each(observer)` borrows each payload using the
selected family's map rules; empty List, absent Optional and Result's Err skip
the observer. Both discard the callback result and retain the original value.
`pair_with(project)` retains each payload beside the borrowed projection result.
`filter_not(predicate)` retains payloads for which the borrowing Bool predicate
returns False.

These four operations keep the semantic family and native-error context;
payload-dependent families rebind after pair_with.
Payloads move without requiring copies. Library callbacks use `BorrowCallable`
and are consumed; native closures are borrowed and thin pointers are copied.
Deferred families retain their evaluation timing and may keep the callback
borrow until execution or disposal. Keep such callbacks alive and unmoved;
overlapping mutable captures still follow Mojo's aliasing rules. A raised error
stops eager processing and destroys remaining inputs and partial output.

`pipeline_values(dictionary^)` selects values of Dict or StringDict. Keys,
key order, native hasher type and container type survive each transformation.
The value type may change repeatedly through map, filter_map, compact and
pair_with without selecting another family. Callbacks must be repeatable;
values and keys can be move-only. Use `.raising[E]()` for native errors as usual.
`pipeline(dictionary^)` continues to treat the entire dictionary as one value.

<!-- example: docs/examples/dictionary_values.mojo -->

`then(stage)` consumes the whole current value once, including a Result's Err.
It selects List, Optional or Result for those output types and Identity for
other outputs. Use `then[Family](stage)` when returning a custom carrier, or
`then[IdentityFamily](stage)` to treat a native container as one payload.
The selected native error remains in effect across these transitions.

`fold_left(step, initial)`, `fold_until(step, initial)` and
`reduce_optional(step)` use the existing consuming iterator drivers. Folds
preserve source order and stop immediately on a raised error; `fold_until`
also stops on Break without another pull. Empty `fold_left` returns its initial
value; empty `reduce_optional` returns None. Native steps are borrowed;
library steps use the standalone folds' shared `Binary` contract. The resulting
value selects its family by the same rule as `then`.

`find_map(transform)` consumes items until the first present Optional result,
without another source pull. `fold_map[Monoid](transform)` projects and combines
in order; `combine_all[Monoid]()` combines the elements themselves. Empty input
returns the monoid identity. `sum()` and `sum_by(transform)` infer Int or numeric
SIMD types and preserve every lane; explicit `[dtype, size]` bindings also work.
`min_by(key)` and `max_by(key)` borrow each item, compute its key once, and keep
the first item on ties. Empty extrema return None. Consuming projections accept
repeatable library callables, including mutable state; borrowing keys use
`BorrowCallable`. Native callbacks remain borrowed. Monoid and callback errors
must agree when both can raise. These eager reductions select the result's
native family and preserve the selected native error for subsequent stages.

Structural mapping methods keep the selected family. `fill(value)` copies a constant
into each payload position; `replace(old, new)` copies `new` into positions
equal to `old` and moves other payloads unchanged. `tuple_left(value)` and
`tuple_right(value)` pair each payload with a copy of the constant. `void()`
discards payloads while retaining the carrier shape and stored errors.
Constants must be Copyable; pairing and discarding still support move-only
source payloads. Deferred families perform these transformations when run.

`compact()` removes absent inner Optional payloads through FunctorFilter.
`flatten()` removes one layer of the same Monad family, preserving the
error type of both Result layers. `ap(values)` applies stored library callables
to an already evaluated carrier of arguments. Optional and Result can consume
single-use callables; List forms a Cartesian product in left-major order and
requires copyable operands. Validation accumulates stored errors, and deferred
families defer application. All eight methods retain the family's native error
contract and embedded origins.

`if_effect(on_true, on_false)` selects a zero-argument factory using the Bool
inside the current Monad. An absent Optional or failed Result invokes neither
factory. Both branches must produce carriers of that family with the same
payload and stored error types. Native errors must match the selected
`.raising[Error]()` context; library factory errors must be mutually compatible.
List conditions can select a branch repeatedly, so both factories must support
repeated calls. Optional and Result support single-use factories with move-only
captures. Reader and other deferred families retain their usual timing and can
join distinct branch representations. Native closures are borrowed for the
effect's lifetime, while native thin pointers and library factories are owned.

`par_map_n(others, mapper)` and `par_product_n(others)` combine up to eight
evaluated Result operands, including the receiver, and accumulate stored errors
in operand order. Native mappers receive separate payload arguments; library
callables consume the flat payload tuple. An empty `others` tuple produces a
one-element tuple or invokes the unary mapper and never calls the error
combiner. `par_traverse(transform)` and `par_sequence()` accumulate stored
errors across the source traversal. Native raised errors still stop immediately.
The `par_` prefix denotes error accumulation; it does not start concurrent work.

List-valued stored errors infer ordered concatenation. Supply an error Semigroup
positionally, such as `.par_map_n[StringMonoid](others, mapper)`, to select another
policy. When the combiner and callback can both raise, their native errors must
agree. N-ary accumulation retains the selected source family. Accumulating
traversal returns a Result pipeline, allowing dependent `.flat_map` calls;
explicit `.traverse[ValidationFamily[Policy]]` retains Validation instead.

Stored thin pointers work for `par_traverse`, `map_n` and `par_map_n`, including
mixed register/memory operands and no-value callbacks. N-ary calls support one
through eight operands. Deferred families own the pointer value, so reassigning
the caller's pointer variable does not change the pending computation. Captured
native closures remain borrowed for that computation's lifetime.

Effectful terminals consume an iterator or owned iterable into an explicit
Monad target. `all_effect[Target](predicate)`, `any_effect[Target](predicate)`
and `find_effect[Target](predicate)` borrow each item and require a Bool inside
the target effect. Each branch stops at its decisive answer without another
source pull. Empty input yields True, False or an absent Optional respectively.
`find_map_effect[Target](transform)` consumes each item and stops at the first
present Optional inside the effect. An absent outer Optional or stored Result
error still stops the entire computation according to the target's rules.

`fold_effect[Target](initial).run(step)` binds the initial accumulator before
admitting a consuming binary callback. This ordering lets Mojo diagnose wrong
argument conventions without inferring the accumulator at the same boundary.
`run` returns a Pipeline in the target family; `get()` extracts its effect.
The binding stage owns the source and initial value but evaluates no callback.
Existing `Piped.fold_effect(step, initial)` retains its original syntax.
`fold_map_effect[Target, Monoid](transform)` consumes items into effectful monoid
values and combines them in order, starting with the identity.

These operations require repeatable library callbacks; consuming unary and
binary callbacks may use mutable receiver state. Reader and State defer source
pulls and callbacks until execution. Monoid identity creation happens before
source binding even for a deferred target; combinations happen inside the effect.
Native callback and monoid errors retain their exact types. Validation's
Applicative-only policy is not a Monad target for these dependent operations.
Arrays use O(N) temporary List storage to avoid moving Mojo 1.2's owning Array
iterator; their elements still move once without copying. Other native iterators
continue from their current position.

`traverse[TargetFamily](transform)` and `sequence[TargetFamily]()` continue in
the target effect family. `traverse_tap[TargetFamily](effect)` borrows each
payload, runs its effect and retains the original on success, discarding the
effect's payload. `filter_effect[TargetFamily](predicate)` runs a borrowing
effect returning Bool and retains the originals whose result is True. Both
require a Traversable source; filtering also requires FunctorFilter, such as
List or Optional. A subsequent `map` operates in the target family.

The target controls sequencing: Optional and Result stop at the first absence
or stored error, Validation accumulates stored errors, and List produces
branches. List traversal into Reader defers callbacks and filtering until `run`;
`get()` does not execute them. Native raised errors keep their exact type and occur
when the callback runs. Callbacks may borrow payloads containing origins.
A library BorrowOnceCallable works with single-use sources such as Optional;
List needs repeatable callbacks. Original move-only payloads are supported
when the target does not need to duplicate them; List branching requires copies.

`traverse_filter[Target](transform)` consumes payloads into effects containing
Optional values, then compacts them through the source's FunctorFilter.
`sequence_filter[Target]()` does the same for effects already in the source.
Both preserve the source shape inside the target; an inner None is filtered,
while a failed target effect follows its normal failure policy.

`flat_traverse[Target](transform)` consumes payloads into effects containing
another source-family carrier. It flattens one source layer inside the target.
`flat_sequence[Target]()` accepts those effects directly. The source must be
both Traversable and Monad, and nested Result errors must match the selected
source family, including their origins. Target failures remain separate.

`traverse_void[Target](effect)` and `sequence_void[Target]()` consume native
iterators or owned collections and discard successful outputs without building
an output collection. Result sources instead use their traversal, preserving
source errors: traversing `Result[Int, String]` into Optional returns
`Optional[Result[NoneType, String]]`. Stored source errors skip callbacks.
Native source loops require repeatable callbacks; Result traversal can consume
a OnceUnary once. Array inputs use the shared safe source conversion.

Compaction and flattening happen inside the target effect, so failures skip
them and deferred targets postpone them. Source-family traversal retains its
own callback-construction timing. Raised callback and postprocessing errors
keep their exact types; none becomes a stored target error automatically.

`map2(other, combine)`, `product(other)`,
`map_n((other, ...), combine)` and `product_n((other, ...))` retain the current
Applicative family. The n-ary forms accept one to eight total operands; native
functions take separate payload arguments, while library Unary callables take
one tuple. Operands are already evaluated and are consumed once. Result keeps
its first stored error, Optional skips absent inputs, and List produces
Cartesian combinations. Selecting `ValidationFamily[Semigroup]` explicitly
accumulates stored errors through the same operations.

<!-- example: docs/examples/selected_workflow.mojo -->

This checkout selects its native error once, traverses into Result, folds the
collected amounts, and combines shipping and tax. Invalid amounts remain stored
errors; transport failures remain native raised errors. Existing `Piped` remains
available, including operations not yet exposed through `Pipeline`.

A generic bind wrapper retains a family parameter (`I: Monad`, optionally
`I: Monad = ResultFamily[E]`) and forwards `I.BindCompatible[V, F]`,
`I.Element[V]`, `I.Bound[V, F]` and `I.BindError[V, F]`. This lets Mojo check
the full carrier and its origins when the family is selected. Naming a concrete
`ResultFamily[E]` in a generic constraint can inspect the callback too early;
an output equality alone does not supply the projection proof. This applies to
generic algebra bind wrappers too. Ordinary calls need no extra arguments;
a default family also preserves a wrapper's existing call syntax.

<!-- api: functions -->

## Chain ten stages with pipeline

<!-- example: docs/examples/chained_pipeline.mojo -->

`total("1999", 3, 10, 499)` runs ten `then` stages: plain functions, two
closures that capture `percent` and `shipping`, and two partials. The price
`1999` cents times 3 is `5997`; the 10% discount gives `5398`, the `-500`
coupon `4898`, shipping `5397`, and 8% tax `5828`, which rounds to the nickel
as `5830` and prints as `total: $58.30`. With `"19.99"`, `parse_cents` raises
`PriceError`, no later stage runs, and the program prints
`invalid price: 19.99`.
The entry point selects `PriceError` once; subsequent pure stages retain Never.

## Bind leading arguments with partial

<!-- example: docs/examples/partial.mojo -->

`partial(twice, value)` copies `4` when it is built and passes a fresh copy on
each call, so `doubled()` returns `8` twice. `partial(scale, 3)` binds the first
argument, and `triple(5)` returns `15`. `partial` binds only a positional
prefix, so the keyword `base=2` is bound by the closure `basetwo`, which
returns `18` for `"10010"`.

## Compose effectful functions

`kleisli[Family](parse).then(validate).map(render)` stores one computation for
later calls. `then` passes each successful payload into the next effectful
function. `map` transforms the payload inside that effect. The family supplies
sequencing: Result skips later stages after an `Err`, Optional after absence,
and List expands each branch in order.

<!-- example: docs/examples/kleisli.mojo -->

Both `piped(values^).map(chain)` and `iterated(values^).map(chain)` accept the
chain directly and borrow it without copying its callbacks. The eager form
maps immediately; the iterator calls it as elements are pulled. These forms
keep each returned Result as an element. Use
`.traverse[ResultFamily[String]](chain)` to gather successes into one Result
and stop at the first stored error. Direct `Result.map(chain)` and
`Result.flat_map(chain)` work as well; `flat_map` sequences the returned Result.

`chain.call(input)` borrows shared callbacks, `chain.call_mut(input)` reuses
mutable callback state, and `chain^.call_once(input)` consumes the chain.
Deferred families such as Reader and State retain the borrowed callbacks until
the resulting computation finishes; consuming invocation transfers ownership
instead. Keep a borrowed chain alive and unmoved while its iterator or deferred
results still need it. Automatic callback adaptation uses shared calls; lazy
mapping also requires that the call cannot raise. A stored Result error remains
ordinary data and is allowed in a lazy iterator.

`.compose(before)` prepends an effectful function of the same family;
`.contramap(prepare)` prepends an ordinary input transformation. All four
composition methods consume the previous chain and the new callback. Owned
captures move into it; captured references keep their native origins. A chain
can be copied explicitly when all its callbacks are copyable. Native raised
errors remain separate from Result errors and must agree across reached stages.

For generic native forwarding, keep `A`, `R` and `E` as the complete native
signature, `F: def(var A) raises E -> R`. Inside that generic wrapper, construct
`NativeUnary[A, R, E, F, True](f^)` from `fp.callables` before passing it to
`kleisli[Family]`. This fixes the signature evidence across module and package
boundaries on Mojo 1.1. A Result family also needs signature evidence that `R`
is its exact carrier, including stored-error origins:
`R == ResultFamily[Failure].Pure[ResultFamily[Failure].Element[R]]`.
