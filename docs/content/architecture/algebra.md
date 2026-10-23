# Algebra and effects

`fp.algebra` defines Functor, Filterable, FunctorFilter, Applicative, ApplicativeError, Monad, Traversable, Semigroup and Monoid
interfaces with instances for native values. `fp.effects` builds Reader, State
and Writer computations on those interfaces and combines effects through monad
transformers.

Instances are selected at compile time. Computations use concrete Mojo structs,
ordinary calls and native ownership and error handling, so their types and
origins remain available to the compiler throughout composition.

## Scope

| Kind | Members |
|---|---|
| Interfaces | `Functor` (`map`), `Filterable` (`filter`), `FunctorFilter` (`filter_map`), `Applicative` (`pure`, `map2_lazy`), `ApplicativeError` (`fail`, `or_else`), `Monad` (`flat_map`), `Traversable` (`traverse`), `Semigroup` (`combine`), `Monoid` (`empty`, `combine`) |
| Derived operations | `map2`, `ap`, `flatten`, `sequence`, defined once over the interfaces |
| Native instances | `IdentityFamily` (a bare value), `OptionalFamily`, `ResultFamily[E]`, `ValidationFamily[S]`, `ListFamily`, using the standard carriers |
| Monoids | `StringMonoid`, `ListMonoid[A]` |
| Transformers | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`; `Reader`, `State` and `Writer` are these over `IdentityFamily` |

An instance is a compile-time dictionary: a type whose operations are static
methods and whose result and error types are associated aliases. The public free
functions forward to it, and the caller selects it explicitly:
`map[OptionalFamily](f, value^)`. List's applicative combination is Cartesian in
left-major order.

## Filtering families

`Filterable` is independent of `Functor`: changing a payload's type and removing
it impose different constraints. `Array` maps while keeping its length, but
cannot represent an arbitrary filtered length in the same type. `Result` maps
its success value, but rejection needs an explicit error policy. Neither has
an automatic filter.

A family supplies `Element[V]`, `Filtered[V, P]`, `FilterError[V, P]` and static
`filter(predicate, value)`. The predicate implements the public `BorrowCallable`
contract: it borrows a payload and returns Bool, preserving its exact failure
type. Third-party instances call it through `invoke_borrowed`; no private
library helpers are required. Eager families preserve accepted payloads and
origins in their native carrier. A deferred family's concrete output type may
include the predicate, with evaluation and errors at its own invocation boundary.
Native callbacks enter borrowed; deferred results keep that borrow alive.

ListFamily and OptionalFamily provide public instances. Native pipeline
adapters cover Deque, LinkedList, Dict and StringDict; see
[container filtering](functions.md#container-preserving-filter) for their
contract and shared traversal. For pure terminating predicates, filtering with
true is identity, filtering with false gives the empty carrier, and successive
filters equal a single short-circuit conjunction in retained values. With
effects, eager stages have their specified separate call order instead.

## Design rules

1. **Keep associated types local.** Each result and error type is
   an associated alias (`Mapped[V, F]`, `MapError[V, F]`, ...) that names only
   the instance's own parameters and their immediate associated types (`F.Out`,
   `F.Error`, `S.Out`). No dictionary member names an executor, a run selector or
   a conditional chain over other dictionaries, so naming a family costs no
   type-level evaluation. Put behavior in methods, whose bodies are elaborated
   only for concrete uses.
2. **One struct per operation.** A deferred computation is a concrete struct
   that stores its inputs and runs itself: Reader has `_ReaderPure`,
   `_ReaderMap`, `_ReaderBind`, `_ReaderAsk`, `_ReaderLocal`, `_ReaderLift`,
   `_ReaderLoop` and `_ReaderChoice`, and State has the corresponding
   `_State*` structs plus `_StateGet` and `_StateModify`. A composed
   computation's type records its tree of operations directly.
3. **Native movement.** Values move through `var` arguments and `deinit self`.
   Hot paths use plain fields and untagged `MaybeUninit` slots
   (`callables.products._take_pair`) rather than `Optional` or `Variant` storage.
4. **Fixed-arity callbacks.** Operations take `Unary`, `Binary` (combiners) and
   `Thunk` (lazy right operands) in shared, exclusive or consuming modes; see
   [callables](callables.md#fixed-arity-protocols). Native functions and
   closures enter `map`, `flat_map` and `traverse` borrowed, as a
   `_NativeUnaryRef` whose origin a deferred computation then carries, and
   `modify`, `censor` and `local` move them into a `NativeUnary`. Their
   signatures compare the callback's input with the carrier's element, origins
   included. Library values such as partials enter directly.
5. **Give each transformer its own type.** Each transformer is a struct, and
   each native family implements its own methods.
6. **Exact errors and origins.** Every callback and computation exposes its
   native `Error`. Errors combine through `_internal.errors`: one exact type or
   `Never`. Reader runs as `run[o](deinit self, ref[o] env)`, and a result that
   keeps a reference into the environment carries `o`; no origin is widened.

### Why the core is shaped this way

The first implementation described every operation with a generic tagged plan,
reached result types through chains of conditional aliases and passed every
callback through per-call argument metadata. A program that only constructed a
`Reader[Int]` value took over three minutes to compile, because naming the
family made the compiler verify the whole effects machinery symbolically. The
cost was in the type-level program (parameter verification and inlining).

The rules above were chosen to make compile cost scale with the user's program.
With them, small algebra and effects programs build from an empty cache in
3–6 seconds on Linux x86-64, and each additional transformer layer adds about a
tenth of a second ([measuring compile time](../contributing/benchmarks.md#measuring-compile-time)). At O3, Reader, State, OptionalT, ResultT and
Writer pipelines built from `map`, `flat_map`, `map2`, `ask`, `get` and `modify`
compile to the same instructions as hand-written code, and list traversal into
Reader, State, `OptionalT[Reader]` or `ResultT[State]` runs at 1.15–1.25× a
native loop.

## Ownership and invocation

- Operations consume their carriers and library callbacks; a native function or
  closure given to `map`, `flat_map` or `traverse` is borrowed, until the call
  returns for an eager instance and until the computation runs for a deferred
  one. No payload, capture or callback is copied implicitly.
- A callback that runs at most once is called with `call_once`; one that may run
  several times is called with `call_repeated`, after asserting
  `RepeatableUnary`, `RepeatableBinary` or `RepeatableThunk`. A consuming-only
  callback is therefore rejected wherever a callback repeats. All of these are
  public, so third-party instances need no private code.
- A payload that must be duplicated across branches (List's Cartesian
  application, `get`, `listen`, replayed deferred computations) must be
  `Copyable`. An internal adapter is `Copyable` exactly when its stored owners
  are; copying never turns a consuming callback into a reusable one.
- A stored `Err` is data. Native exceptions propagate unchanged and never become
  stored errors; `attempt` is the explicit conversion.

## Evaluation order

- List operations run left to right.
- A lazy right operand (`map2_lazy`) is produced zero or one times per
  combination. An absent, failed or empty left side skips it. A produced value is
  copied for later branches of a multi-branch carrier.
- `pure` never raises. Constructing a deferred computation never raises; running
  it raises the exact common error of the stages it executes.
- Traversal keeps the source's shape and the callback order. It checks that the
  accumulator is still live before every pull, calls the producer once per pulled
  item, and stops pulling after a failure or absence. Any owned iterable or
  iterator can be the source, and an iterator is never restarted.

## Traversal

`Applicative.collect` is one private pull loop, `_loop[V, F, K]`, run with an
append policy. `K: _Accumulate` supplies `Acc`, `Item`, `start`, `live` and
`combine`.

- The default `_loop` uses only `pure`, `map` and `map2_lazy`: the lazy right
  operand pulls each item and is skipped once the accumulator has failed. It
  serves any Applicative whose accumulator keeps one type.
- Identity, Optional, Result and List each implement `_loop` as one native loop
  with early exit; List carries inactive branches unchanged.
- Reader delegates to its base's `_loop`, with a continuation that runs each
  produced computation on the borrowed environment.
- State delegates to the dependent fold driver: probe the base carrier for a
  live branch, pull one item, call the producer once and bind the prepared
  computation across live branches, each with its own state. The base carrier
  must keep one type, so a deferred base under State traversal is rejected at
  compile time.
- OptionalT, ResultT and WriterT wrap the policy (absent or failed accumulators
  stop; logs combine in order) and delegate to their base's `_loop`, so pull and
  producer counts are the same over eager, deferred and third-party bases.

A deferred traversal is one concrete loop computation, never a chain of
computations that grows at run time.

### Traversal conveniences

`algebra._traversal` owns the derived traversal policies. `traverse_void` supplies a
`NoneType` accumulation policy to the same `_loop`; it does not collect a List
and then throw it away. Its associated result and error types come directly
from the target's `_Looped` and `_LoopError`, including deferred targets and
transformer layers.

`traverse_tap` adapts a borrowing effectful callback into an owned callback:
borrow the input, obtain its effect, then map the canonical retained-value
callable over that effect. Source `traverse` still owns shape and source errors;
the target's `map` owns branching and effect errors. `_Retained` moves its value
when called once and offers a repeated receiver only for copyable values.
The borrowing adapter is `_EffectRetain` in `algebra._sequencing`;
`_TraverseTap` remains a private alias for traversal consumers. Result
observation and fluent monadic sequencing use the same adapter.

The generated Piped, Iter and free-function overloads only adapt native
callback signatures and select the source family. They contain no pull loop
or duplicated error handling. `traverse_void` admits native owned iterable
sources and Result. Its Result path composes the callback with an effect-payload discard through the existing
`Composition`, then delegates to `ResultFamily.traverse`. This preserves source
errors without another branch implementation. Custom Traversable-only sources
use `traverse_tap` or supply an owned iterator for `traverse_void`.

`flat_traverse` and `traverse_filter` share `_traverse_then`: source traversal
followed by a target `map`. The postprocessing callables delegate to the existing
`flatten` and `compact` operations. Custom sources supply `Traversable` plus
`Monad` or `FunctorFilter`; they implement no new combinator primitive. Keeping
the second step inside the target effect preserves failure and deferred timing.
For List sources this deliberately uses a temporary collection and a second
linear pass instead of adding a fused traversal/filtering protocol.

`filter_effect` uses the same borrowing adapter and `_Retained` callable as
`traverse_tap`, with selection enabled. The retained callable converts each Bool
decision into an Optional original through the same selection function used by
ordinary filtering; traversal then compacts it. Branching targets admit the
repeated retention receiver only when the original is copyable. `sequence_void`
and `flat_sequence` supply the existing identity callback to their traversal
policies. Generated signatures check native source shape and nested payload
shape, including Result's stored-error origins, at admission. Explicit native
Result source and target families must preserve the same stored-error type and
origins as the values they receive.

Generic admission reuses `_EntryError` and `_propagate_error` to validate an
explicit error witness when Mojo cannot reduce a symbolic family error. A native
generic wrapper that decomposes a nested `Optional[Result[B, E]]`
return may lose the relationship between the function trait's parameters and
its surrounding parameters on Mojo 1.1. Such a wrapper can fail admission even
with `E`/`X` evidence. A library callable struct declaring that `Out` preserves
the relationship; direct native callbacks with known types remain supported.
Do not bypass the Result origin constraint to admit an unproven wrapper.
The shared common-error expression retains its existing spelling so previously
valid generic Result forwarding continues to compile.

### Fluent monadic sequencing

`flat_tap` and `before` bind `_EffectRetain` over the source family. It borrows
each original for its callback, then maps `_Retained` over the resulting
effect. `followed_by` uses `_BorrowedUnary` to call the factory and discard the
original. `_IgnoreInput` adapts a zero-argument factory to the same borrowed
callback contract. Families supply only their existing `flat_map` and `map`;
no container implements a sequencing loop or a new primitive.

`flat_pair_with` selects the existing paired mode of `_EffectRetain` and
`_Retained`. That mode moves each projected payload into `(original, projected)`;
repeated calls copy only the original. Piped, Iter and direct Result therefore
share the same pairing implementation, with no additional family primitive.

`_Retained` admits a repeated receiver only when the original is copyable.
This gives List its per-branch copies and lets Optional, Result, Reader and
State move single-use originals. The family's receiver selection preserves
short circuits, transformer behavior and deferred timing. Result's direct
methods share `callables._retention._Retain` with `_EffectRetain`; its error and whole-outcome observers then use
the existing Result transformation to restore the appropriate constructor.

Iter uses the same continuations through a private `_IteratorMap` Functor.
That adapter supplies native lazy mapping; the existing `flatten` owns inner
iterator advancement. It does not implement Monad or replace native iteration.
An internal `_MutableBorrow` receiver bridges owned native closures and
mutable factories to shared retention. Public borrowing callback protocols
keep their shared and consuming receivers.

Generated methods handle native shape and callback admission. Native callbacks
in Piped are borrowed through the existing pointer adapter, while Iter stores
them by value and invokes them with mutable access. Mojo 1.1 preserves generic
parameter names in native callable witnesses, so the sequencing boundary uses
`P`, `R`, `X` for borrowing callbacks and `R`, `X` for factories. A generic
wrapper can forward `.flat_tap[P=P, R=R, X=X](inspect)` or
`.before[R=R, X=X](make_next)`. `R` names the complete effect result, including
its origins; Result additionally requires its stored error type to match the
source. The small native signature adapters retain these names and delegate
receiver ownership, retention and error propagation to their canonical owners.

### Fluent combination

Fluent `map2` delegates to the existing Applicative combination. `product`
supplies the canonical pair callback to that same operation. Fluent `ap` and
free `ap` share `callables._transforms._Apply`, which consumes a stored unary
callback and its argument through `call_once`. This lower-level owner lets
Result use the same adapter as the algebra layer. No family adds another
application primitive. The shared value
thunk in `callables._transforms` supplies an already evaluated right operand;
`map2_lazy` remains responsible for deferred operand construction.

Result's combination and stored-error policies live in
`algebra._result_accumulation`; `ResultFamily.map2_lazy` and ValidationFamily
delegate to them. They use the owned transform primitive in `data._result`. Native
binary callbacks are borrowed through `callables.native`, while library
callbacks use the existing once/repeated receiver dispatch. Signature adapters
are generated separately for native carriers and explicit families because
Mojo needs the native shape as evidence during overload selection.

`algebra._nary._ProductRun` owns n-ary sequencing. It maps the first payload
into a singleton tuple, then folds additional carriers through `map2_lazy`
with a flat tuple append callback. `map_n` maps the supplied callback over
that product. No container adds a new primitive. Native `Tuple.concat` moves
tuple fields; Optional cells retain unvisited operands so a raised construction
error destroys them. The Optional cell type is shared with stored compositions.

The execution driver is variadic and receives exact output and error evidence,
which it checks at each boundary. Inferred native carriers can spell their
flat result directly. Other families can change their concrete computation type
at each combination, so generated type descriptions cover one to eight
operands; they contain no execution or error-handling code. Native callback
adapters also cover one to eight arguments because Mojo distinguishes a fixed
function signature from a variadic signature. They consume tuples using the
native `consume_elements` operation and call through the existing unary/binary
boundaries or the generated higher-arity boundary. Library callbacks keep their
existing Unary receiver contract over one tuple.

### Dependent folds and conditions

`fold_effect` passes the current accumulator and next source element to a
repeatable binary callback. Its next action depends on the preceding result,
so it needs `Monad`, rather than independent Applicative accumulation.
`any_effect` and `all_effect` use the same fold with a Bool accumulator and a
borrowing predicate. Their live policy stops each branch at its decisive Bool.

`algebra.protocols._bind_loop` owns source advancement, the live-branch probe
and dependent binding. The default `Monad._fold` delegates to this driver.
It maps a probe over the accumulator carrier before pulling another element;
failure or absence therefore ends the loop without another pull. After one
preparation call per element, it binds a step across live accumulators. An
inactive accumulator is lifted unchanged, so a finished List branch appears
once in the output, without being expanded by later predicate results.

The default driver requires the carrier type to stay the same across steps.
Reader and State override `_Folded`, `_FoldError` and `_fold` to store one
deferred computation. Running it delegates to the base fold, adapting each
step to the borrowed environment or to `(accumulator, state)`. State traversal
also delegates to this driver: its preparation produces one action per element,
while a dependent fold prepares the element itself. No second State pull loop
or per-container reduction implementation is needed.

Branching copies prepared items because each live accumulator needs its own
input. Result, Optional and Identity move them. The fold itself does not copy
the accumulator; any copying required by the target effect's own operations
still applies. The driver adds constant stack depth and holds the accumulator
carrier and one source element. List's map and bind allocate carriers and its
number of branches can grow with every step.

`if_effect` is a bind with one Bool continuation. `_choose_effect` owns branch
selection and invokes only the selected zero-argument factory. Once-only
factories work with effects that invoke the continuation at most once; List
requires repeatable factories. The existing `_Joined` hook represents different
concrete Reader or State action types with the same successful payload.
Native factory boundaries retain `U`/`Y` for the true branch and `W`/`D` for
the false branch because Mojo 1.1 keeps those parameter names in function
witnesses. These two signature adapters share the same receiver dispatch and
branch-selection implementation.

## Transformers

| Family | Computation | Run |
|---|---|---|
| `ReaderT[M, R]` | A `ReaderAction`: borrows `R` and returns `M`'s carrier | `run[I](computation, env)` |
| `StateT[M, S]` | A `StateAction`: consumes `S` and returns `M`'s carrier of `(A, S)` | `run[I](computation, state)` |
| `WriterT[M, W]` | `WriterValue`, wrapping `M`'s carrier of `(W.Value, A)` | `run_writer[I](value)` |
| `OptionalT[M]` | `M`'s carrier of `Optional[A]` | The base's run |
| `ResultT[M, E]` | `M`'s carrier of `Result[A, E]` | The base's run |

- A transformer uses its base only through the base's `Monad` methods, so any
  Monad, including another deferred family or a third-party instance, can be the
  base. `OptionalT[IdentityFamily]` and `ResultT[IdentityFamily, E]` are
  `OptionalFamily` and `ResultFamily[E]` themselves.
- Each combinator's `run` checks family membership with an inline `comptime
  assert`, so a computation of the wrong family is reported before the base's own
  checks.
- `local` runs its source with an environment that lives only for that run, so a
  base whose result keeps the environment is rejected at compile time.
- **Stack order is observable.** `ResultT[State[S], E]` returns
  `Tuple[Result[A, E], S]` and keeps the state reached before a failure;
  `StateT[ResultFamily[E], S]` returns `Result[Tuple[A, S], E]` and has no state
  after a failure. Nested sums keep absence and stored errors distinct. Neither
  order rolls back external mutation.
- Writer operations use the base's own operations, so over a deferred base a
  Writer value stays deferred; `run_writer` unwraps it without running it.
  `pure` over WriterT requires a monoid whose `empty` does not raise.

### Choice between computations

A layer's bind step returns either the callback's computation or `pure` of the
absence, and over a deferred base these have different types. `Monad` has three
private members, `_Joined[L, R]`, `_join_left` and `_join_right`:

- eager families require `L == R`;
- Reader and State hold either computation in a native `Variant` that implements
  the family's action trait and runs the selected branch; nested choices nest;
- Writer joins its wrapped base carriers; OptionalT and ResultT delegate to their
  base.

A deferred Monad used as a transformer base overrides these members. Both
branches must belong to the same family, and running the selected branch copies
neither its payload nor its captures.

## Third-party instances

A third-party instance implements the members of the interfaces it claims (the
[reference](../reference/algebra.md) lists them). It receives callbacks through
their contracts and calls them with `call_once`, or with `call_repeated` after
asserting the matching `Repeatable*` predicate. A deferred instance whose
accumulator changes type between steps overrides the private `_Looped`,
`_LoopError` and `_loop`; one that overrides only `collect` works on its own but
cannot be the base of a layered traversal. The test suite implements every public
interface, including `ReaderAction` and `StateAction`, from outside the library.

An eager Monad whose carriers keep one type also inherits effectful reductions
through its existing `pure`, `map` and `flat_map`. A deferred family overrides
the corresponding `_Folded`, `_FoldError` and `_fold` hooks to retain the source
and callbacks until execution, as Reader and State do.

## Mojo 1.1 constraints behind the encoding

- A default method in a derived trait cannot satisfy an ancestor trait's
  requirement for a parametric struct under package precompilation, so receiver
  modes are separate traits chosen by dispatch rather than one trait hierarchy
  with defaults.
- A conformer's method signatures must use the trait's associated names
  (`Self.Arg`), and a conditional conformance to a derived trait must restate
  the ancestor's `where` clause. Only `mojo precompile` detects violations.
- Member aliases of structs instantiated with symbolic parameters are not
  reduced, so result types are spelled structurally where generic code needs
  them.


## Accumulating Result validation

`ValidationFamily[S]` is an alternative Applicative over native
`Result[A, S.Value]`. It changes how independent failures combine while
retaining Result storage and its stored error type. `Semigroup` owns the
associative ordered combination contract; `Monoid` inherits it and adds the
identity operation. Validation needs no identity error: empty traversal
starts with a successful empty accumulator.

Result's canonical pair-combination kernel accepts a private stored-error
policy. `ResultFamily` skips the right thunk after a left error. Validation
forces it once, combines two errors with `S.combine`, and retains a single
error when only one side fails. The successful branch and its callback
ownership have one implementation. Native errors propagate unchanged through
the same exact-error helpers and always stop work.

Both policies adapt the payload accumulator to an accumulator of Result and
run the existing `_map_accumulate` source loop. Its liveness check stops on
an ordinary Result error, or continues on a validation error. Successful
payload accumulation is delegated to the original rule; after a stored error,
later successes are dropped and later errors are merged. No second iterator
loop, error buffer, container builder or callback execution protocol is added.
The n-ary product runner uses the same Applicative primitives and consumes
its operand slots once, including cleanup if combination raises.

Fluent `par_map_n`, `par_product_n`, `par_traverse` and `par_sequence`
select this family. Products use the existing n-ary runner directly;
sequencing supplies the canonical identity callback to traversal. Generated native
signatures adapt callback arity and source shapes, then delegate to the
existing n-ary and Traversable operations. Mojo 1.1 needs separate inferred
and explicit policy signatures for owned variadic arguments; their execution
is identical. Admission checks preserve exact carrier, payload and stored-error
origins. Generic native forwarding uses the established signature names and,
when a generic function's result shape needs explicit evidence, the public
`NativeUnary` adapter with the family's associated error type.

For `par_sequence`, the native boundary spells the effect as `S.Error` on List
and Iter, and `Never` on Optional and Result, which cannot combine two errors.
The existing exact-error traversal adapter checks that declaration against the
family operation. This lets generic callers forward `S.Error` without exposing
the internal identity callback or weakening native error identity.

This family deliberately does not implement Monad. A dependent validator
cannot run without its preceding successful payload. Compose those steps with
Result bind or Kleisli, and use validation to collect errors across independent
inputs. No runtime Validated wrapper or thread scheduler is needed.

## Shared error handling

ResultFamily, ValidationFamily and ResultT implement this capability. ReaderT,
WriterT, OptionalT and StateT lift it from an error-capable base Monad; StateT
requires copyable state for recovery.

`ApplicativeError` extends `Applicative` with two family primitives:
`fail[A](error)` constructs a stored failure with success type `A`, and
`or_else(handler, source)` replaces a stored failure with the handler's effect.
Cats uses this split as `raiseError` and `handleErrorWith`; its other recovery
operations derive from these and the ordinary Applicative operations
([source](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/ApplicativeError.scala)).
Mojo operations requiring bind constrain `Monad & ApplicativeError`;
an additional marker trait is unnecessary. This lets ValidationFamily support
recovery while keeping its existing Applicative-only contract.

The capability names its stored error type `Failure`. Associated `Failed[A]`,
`FailError[A]`, `Handled[V, H]` and `HandleError[V, H]` describe exact returned
carriers and native construction errors, following Functor's existing pattern.
Returning a new concrete Reader or State action type remains valid. Existing
aliases such as `ResultFamily.Error` remain available.

The public entry points are `fail[Family, A](error)`, plus
`piped(value^).or_else[Family](handler)` and
`piped(value^).recover[Family](handler)`. The first handler consumes an error
and returns the same family with the original success type; the second
consumes an error and returns a replacement success value. Generic recovery
keeps the selected family's stored error type. Existing direct Result methods
and inferred Piped Result overloads retain their current contracts, including
`or_else`'s ability to change the stored error type.

### Select one stored-error layer

The explicitly selected family determines which failure is handled. Native
`raises` errors propagate with their exact types; recovery never catches them
implicitly. A failure returned by the handler passes onward without running
the same handler again.

| Selected family | Handled failure |
|---|---|
| `ResultFamily[E]` | Its stored `E` |
| `ValidationFamily[S]` | Its stored `S.Value`, including an accumulated error |
| `ResultT[M, E]` | The inner Result's `E`; failures in `M` pass through |
| `ReaderT[M, R]`, `WriterT[M, W]`, `StateT[M, S]` | The base family's selected failure, when that base supports the capability |
| `OptionalT[M]` | The base family's selected failure; an absent Optional stays absent |

For `ResultT[ResultFamily[Outer], Inner]`, recovery handles `Inner`, even when
`Inner` and `Outer` happen to be the same type. Bare Piped Result inference
continues to select the outer native Result. Lists, iterators, Identity and
standalone Optional do not acquire a stored-error channel. A list of Results
can select `ResultT[ListFamily, E]` explicitly to recover its failed entries.

### Preserve ownership and effects

Recovery consumes the selected stored error once. Success skips the handler
and moves the original payload onward. Native callbacks are borrowed in place;
owned library callbacks retain their existing shared, mutable and consuming
receiver rules. Single-use paths admit consuming callbacks and move-only
payloads and errors. A branching base requires a repeatable handler, invoked
once per selected error branch, with output order determined by that base.
Skipped captures and unvisited branches are destroyed through the existing
ownership machinery. External origins remain part of all payload and error
types, including deferred callback borrows.

The remaining transformers delegate recovery to the base capability.
Reader recovery runs with the same borrowed environment, only when the
computation is run. Writer recovery follows the stack's representation:
`WriterT[ResultFamily[E], W]` has no log in a failed base result, so recovery
returns the handler's log. `ResultT[Writer[W], E]` retains the previous log and
appends the handler's effects. These choices preserve existing transformer
order rather than introducing a separate logging policy.

For `StateT[ResultFamily[E], S]`, failure contains no state. The
recovery contract saves the state supplied to the handled computation and
runs its handler with that state, requiring `S: Copyable`. Cats also restarts
its StateT handler with the input state
([source](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/data/IndexedStateT.scala)).
In Mojo, this means retaining the input and running the source on a copy; a
branching base may require further copies for repeated handlers. The state is
the input at this recovery boundary, not necessarily the beginning of the
whole pipeline. Copyable does not guarantee a deep snapshot of referenced
objects, and external mutation is not rolled back.

For `ResultT[State[S], E]`, the failed Result is paired with the updated state.
Recovery continues from that state and introduces no copying requirement on
`S`. Ordinary State operations keep their existing move-only support; the
copyability requirement applies only to the recovery instance that must save
its input state.

### Shared implementation

The first pass provides the capability, failure constructor, and fluent
`recover`/`or_else` support for ResultFamily, ValidationFamily and ResultT.
Result remains the owner of native branch selection and cleanup; its family
adapters delegate to that implementation. ResultT generalizes its existing bind guard to select either Result branch,
using Result's consuming fold and the base's existing bind and branch joining. Generic `recover` derives
once from error handling and `pure`, without a new implementation per family.
Validation delegates recovery to the same Result machinery and keeps its
accumulating combination policy.

The checks cover direct and imported generic calls, a third-party capability,
move-only errors and handlers, skipped-handler cleanup, ResultT branching,
deferred bases, nested error layers with equal and distinct error types, exact
origins, and native raised errors. Focused checks run at O0 and O3 through
source and package imports, alongside the repository's full gates.

The second pass lifts recovery through ReaderT, WriterT, OptionalT and StateT.
Reader and State generalize their existing bind computations: one private
operation selector chooses base bind or error recovery, while the same
continuations run callback effects. State's continuation takes either the
successful branch's state or the saved recovery input. Writer reuses its
callback-to-base adapter; OptionalT delegates directly and preserves absence.
No transformer catches native raised errors to turn them into stored failures.

Reader and State defer base failure construction until `run`, including its
native construction error. Writer and OptionalT retain their base's construction
timing. Writer failure creates no empty log, so it does not call the monoid.
The separate Reader and State failure actions adapt their native borrowed and
owned invocation boundaries; the base family owns failure construction.

Mojo 1.1 exposes only common traits through a conditional type alias. Error
entry points therefore check `conforms_to(Family, ApplicativeError)` and recover
the native trait witness internally. This keeps the same user syntax and
preserves `OptionalT[IdentityFamily] == OptionalFamily`; no wrapper or error
conversion is introduced.

Conditional recovery adds one shared handler around `or_else`. Its predicate
borrows the selected error. A match consumes the error in the handler; a
non-match reintroduces it with the selected family's `fail`. Both paths retain
the success and stored-error types. Failure construction can raise a native
error, which remains separate from stored failures; deferred families keep the
constructor's usual execution boundary. Success skips both callbacks, and a
handler's returned failure is not tested again.

The predicate guard lives with callable invocation and also serves Result's
existing conditional operations, including `ensure`. Branch joining belongs
to Applicative because choosing between two carrier representations needs no
bind; Validation uses the eager default, and deferred transformers keep their
existing joins. No per-transformer conditional implementation is needed.
Borrowing and consuming callback views share the established receiver dispatch.
Branching requires repeatable predicates and handlers; single-use effects admit
consuming callbacks and move-only stored errors. Native predicate and handler
signatures have separate admission boundaries on Mojo 1.1, with the predicate
adapter preserving its P/S/X witness and the handler using A/R/E.

Error observation uses one handler around `or_else`, shared by explicit-family
Piped methods and inferred Result methods. `tap_err` delegates borrowing and
discarding to the callable observer, then reintroduces the original error
with `fail[A]`. `flat_tap_err` uses the existing effect-retention adapter with
a different finishing operation. That adapter owns callback invocation and
retains the original value; its default finish still maps retained values into
successes for sequencing and traversal.

The error-observation finish first discards observer success payloads through
the shared effect-void operation. It then combines the observer effect with a
lazy original failure through `map2_lazy`. This follows Cats' `onError`
derivation: Result keeps an observer failure, while Validation accumulates
observer errors followed by original errors. Empty List branches and Optional
absence stay empty. Timing, state and logs follow the existing recovery and
combination primitives; no transformer-specific observation engine is needed.

The lazy failure uses the native uninhabited success type `Never`. Its binary
continuation eliminates that impossible success to produce the original
success type `A`. This avoids requiring Copyable on a nonexistent success value
when a branching family caches the right operand. Observer success payloads
are discarded before combination and need not be copyable either. Branching
may still require copying the retained error. The precise native constructor
error is `FailError[Never]` for `flat_tap_err`, and `FailError[A]` for `tap_err`;
constructor and combination errors retain their exact types, including native
errors raised by a Validation semigroup. A short-circuiting observer failure
does not construct the lazy original failure.

Native Result `flat_tap_err` signatures spell the observer return as
`Result[U, E]`, as whole-outcome observation already does. This admission
boundary preserves embedded error origins while supporting generic forwarding;
the body delegates to the same family implementation. Explicit-family methods
check the observer carrier against the family's exact stored-error layer.
Native callbacks remain borrowed through deferred execution, while library
callbacks transfer ownership. Branching requires repeatable observers;
single-use paths permit consuming callbacks and move-only errors.

Success validation binds an `ensure` continuation over the source. The existing
borrowed predicate guard retains accepted values through `pure` and calls the
borrowing error factory only on rejection, then uses `fail[A]`. Source failures
skip the continuation. This requires Monad and ApplicativeError, without adding
a separate marker trait or changing Validation's Applicative-only contract.

Outcome composition first maps successes into `Ok` values and recovers selected
failures into successful `Err` values. This internal materialization uses a
native `Result[A, E]`, preserving exact origins and ownership. It handles only
the selected stored-error layer and does not catch native exceptions. Result's
existing owned fold selects the handler and disposes of the inactive context.
`redeem` maps that fold over the materialized carrier; `redeem_with` binds it.
Both finish after the selected handler, so a handler's stored failure cannot
invoke the other handler. Deferred branches may have different concrete carrier
types; they use the family's existing join operations.

`attempt_tap` binds the existing effect-retention adapter over the materialized
outcome, then restores each retained Result through `pure` or `fail[A]`. Observer
failure or absence bypasses restoration. Branching may copy the retained Result;
single-use paths move it, and discarded observer payloads need not be copyable.
Restoration retains native failure-constructor errors and their execution timing.
The selected family's recovery and bind operations determine state and logs.

No family-specific outcome interpreter is added. Native overloads use the
existing callback reference views. Mojo 1.1 needs separate invocation shims for
the two admitted native signatures (`A/R/X` and `Q/S/Y`); their views share
storage and receiver handling. Native error compatibility is checked at method
admission because body-only comparisons can unify distinct embedded origins.

The approved proposal is complete. Generalized operations retain the selected
stored-error type; error-type-changing Result methods remain available without
extending that behavior to other families.
