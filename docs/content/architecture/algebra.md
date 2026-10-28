# Algebra and effects

`fp.algebra` defines Functor, Filterable, FunctorFilter, Applicative, ApplicativeError, ErrorMapping, Monad, Traversable, Semigroup and Monoid
interfaces with instances for native values. `fp.effects` builds Reader, State
and Writer computations on those interfaces and combines effects through monad
transformers.

Instances are selected at compile time. Computations use concrete Mojo structs,
ordinary calls and native ownership and error handling, so their types and
origins remain available to the compiler throughout composition.

## Scope

| Kind | Members |
|---|---|
| Interfaces | `Functor` (`map`), `Filterable` (`filter`), `FunctorFilter` (`filter_map`), `Applicative` (`pure`, `map2_lazy`), `ApplicativeError` (`fail`, `or_else`), `ErrorMapping` (`bimap`), `Monad` (`flat_map`), `Traversable` (`traverse`), `Semigroup` (`combine`), `Monoid` (`empty`, `combine`) |
| Derived operations | `map2`, `ap`, `flatten`, `sequence`, defined once over the interfaces |
| Native instances | `IdentityFamily` (a bare value), `OptionalFamily`, `ResultFamily[E]`, `ValidationFamily[S]`, `ListFamily`, using the standard carriers |
| Monoids | String/List concatenation, native numeric and boolean policies, `ProductMonoid`, `OptionalMonoid`, `DictMonoid` |
| Transformers | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`; `Reader`, `State` and `Writer` are these over `IdentityFamily` |

An instance is a compile-time dictionary: a type whose operations are static
methods and whose result and error types are associated aliases. The public free
functions forward to it, and the caller selects it explicitly:
`map[OptionalFamily](f, value^)`. List's applicative combination is Cartesian in
left-major order.

## Compose accumulation policies

`ProductMonoid[L, R]` combines a native pair component by component. Identities
and combinations run left component first; a raised error skips the right
operation. Both component error types must be identical or `Never`. The owned
pair splitter moves all fields into ordinary owners before either operation
can fail, so native cleanup also destroys untouched components. Nested product
dictionaries describe larger products without a second accumulation driver.

`OptionalMonoid[S]` gives a Semigroup an absent identity. A sole present value
moves through unchanged; two present values use the existing optional
accumulator. It combines payloads, rather than choosing the first present
alternative. `DictMonoid[K, S]` consumes dictionaries and combines duplicate
values in left/right order through `S`. Native draining and removal move keys
and values without requiring copies. Native table iteration order is not part
of its algebraic identity: laws compare mappings. A failure destroys partial
output and the remaining input; external callback effects are not rolled back.

`IntSumMonoid`, `IntProductMonoid`, `BoolAllMonoid` and `BoolAnyMonoid` have the
native identities zero, one, true and false. Boolean operands are evaluated
before combination. `SIMDSumMonoid` adds numeric lanes independently, sharing
the implementation of ordinary iterator sums. Native overflow and floating-point
rounding remain visible; floating addition is not associative and cannot justify
reassociation. These policies do not introduce parallel reduction.

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
them by value and invokes them with mutable access. The sequencing boundary retains
`P`, `R`, `X` for borrowing callbacks and `R`, `X` for factories. A generic
wrapper can forward `.flat_tap[P=P, R=R, X=X](inspect)` or
`.before[R=R, X=X](make_next)`. `R` names the complete effect result, including
its origins; Result additionally requires its stored error type to match the
source. The shared native reference views accept these bindings and delegate
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

### Map one stored-error channel

`ErrorMapping` supplies one two-arm primitive, independently of recovery.
ResultFamily and ValidationFamily delegate to the existing Result fold.
ResultT maps each inner Result through one base `map`, preserving interleaved
success/error callback order; its base need not implement `ErrorMapping`.
OptionalT uses a mapping-capable base's primitive with the existing Optional
success adapter, preserving absence. ReaderT, StateT and WriterT share the
`_BimapOp` carrier operation in `effects._transport`, which stores both
callbacks and delegates admission and execution to `MapBothContract` and the
checked base runner. A mapping-only base needs no `ApplicativeError` witness.

Selected error operations also respect that capability boundary. Native Result
storage grants no recovery, observation, validation or outcome handling to an
`ErrorMapping`-only family. Intrinsic Result fallback requires the selected
family to implement neither `ApplicativeError` nor `ErrorMapping`; canonical
Result implements the capabilities directly. Thus mapping can be available
without recovery, including for State with move-only state. Explicitly
extracting and reselecting a native Result opts into that carrier's own policy.

The existing `_ReaderHoist` and `_StateHoist` accept an admitted destination
family while keeping their original source action and execution code. Their
three-parameter `_Hoisted` and `_hoist` entry points retain the original family
through delegation, including for local/listen/censor consumers. Reader checks
the actual run origin as well as admission witnesses; its output and native
error keep any environment borrow. State uses `_MapFirst` on `(value, state)`
and runs its source once, without saving, restoring or copying state. Writer
uses `_MapValue` on `(log, value)` and the existing unwrap/apply/rewrap transport
with a destination `WriterValue`; it neither copies nor combines the log.

The source admits an exact destination policy. ResultT reselects the base's
payload metadata through `RebindingFunctor` where needed; the other layers
ask their base for the destination error policy. A raw proposed base must
implement Monad before it can be wrapped. OptionalT, ReaderT, StateT and
WriterT leave an unsupported default candidate unwrapped for normal rejection;
an explicit permitted Monad target remains available. Targets must use the
same constructor and exact environment, state type or log monoid. Reader and
State construction raises Never; their run combines source and base-operation
errors at the actual execution boundary. Writer exposes the base operation's
exact construction error and retains deferred execution. No new interpreter,
second traversal or recovery stage is introduced.

The selected Pipeline target boundary accepts a Functor with an explicit
`ErrorMapping` conformance check. This admits conditional OptionalT aliases
without changing their Identity collapse or requiring casts at ordinary calls.
Core contracts remain capability-bound; generic wrappers use the full source
and target family witnesses described in the
[stored-error design](mojo12-redesign.md#proposed-stored-error-rebinding).

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
same callback reference views for both admitted signatures (`A/R/X` and
`Q/S/Y`). Mojo 1.2 no longer needs separate invocation shims for these names;
each view calls its native invocation owner directly. Native error compatibility is checked at method
admission because body-only comparisons can unify distinct embedded origins.

The approved proposal is complete. Generalized operations retain the selected
stored-error type; error-type-changing Result methods remain available without
extending that behavior to other families.

## Inclusive-or evaluation policies

`IorFamily[S]` is a Monad with a sequential Applicative. `IorValidationFamily[S]`
is a separate Applicative for independent diagnostic accumulation. Both operate
on the same `data.ior.Ior` carrier and share one mapping, combination and
ordered diagnostic-merge implementation. Independent validation has no bind:
continuing after Left without a value cannot select a dependent callback.

The following table gives independent combination, with `+` denoting S.combine
and `f` the value combiner. Sequential combination differs only in the Left
row: it returns the left diagnostic and never forces the right thunk.

| Left operand | Right(b) | Left(y) | Both(y, b) |
|---|---|---|---|
| Right(a) | Right(f(a, b)) | Left(y) | Both(y, f(a, b)) |
| Left(x) | Left(x) | Left(x + y) | Left(x + y) |
| Both(x, a) | Both(x, f(a, b)) | Left(x + y) | Both(x + y, f(a, b)) |

Evaluation is ordered: force the right thunk once, call f once when both values
exist, then combine diagnostics if both are present. Bind calls its dependent
callback before combining previous diagnostics with that result's diagnostics.
The callbacks may consume their receivers. Skipped callback owners and unused
payloads are destroyed exactly once. Any native raised error stops immediately,
keeping its exact type; raising components must share one error type or Never.

Collection supplies `_IorAccumulator` to the existing `_map_accumulate` pull
loop. Right and Both carry the live payload accumulator; Left ends sequential
collection, while accumulating collection keeps pulling for diagnostics alone.
Partial payloads are discarded on failure. Empty input is Right of an empty
List. Iterator sources continue at their current position. No second traversal
loop is added; `_AccumulatePair` belongs to protocols and is shared with Result.
Traversal takes linear loop work, plus callback and diagnostic-combination
costs, and constant native stack space. The output List owns successful values;
all partial values and diagnostics are cleaned up on native failure.

Functor and Monad laws and sequential Applicative coherence assume an
associative diagnostic Semigroup and pure, terminating callbacks. Independent
Applicative laws use the same assumptions; diagnostics need not be commutative.
The laws compare observable values and ordered diagnostics, not destruction
traces or native effects.

### Family admission and generic forwarding

Checked algebra entry points and generated fluent methods evaluate family
admission in their `where` clauses. `Functor.MapCompatible[V, F]`,
`Monad.BindCompatible[V, F]`, and `Applicative.CombineCompatible[V, F, R]` /
`CollectCompatible[V, F]` default to True. Ior overrides them to check diagnostic
origins, callback-result types, and compatible native errors. Result overrides
them to require its exact stored error type and origins. Mapping checks the
source carrier; combination checks both carriers and both callback payloads;
collection checks every produced carrier and the actual repeated loop.
Identity, Optional, Result and Validation share linear producer admission:
iterable item equality, a repeatable receiver, and compatible native errors.
Their custom-accumulator admission also checks the produced item; no copies are
required. Validation retains Result carrier admission and adds its diagnostic
policy's native error to collection admission. Binding checks carrier membership
independently, so a consuming callback remains valid for a single Result. Mapping and binding also require
`I.Element[V] == F.Arg` at the call boundary.

Generic forwarding signatures must now carry the corresponding predicates.
For example, a wrapper around `map[I](f^, value^)` returning `I.Mapped[V, F]`
needs `where I.Element[V] == F.Arg and I.MapCompatible[V, F]`; a wrapper around
`traverse[S, G]` needs `where S.Element[V] == F.Arg and S.TargetCompatible[G, V, F]`. Bind uses the same
input equality with `I.BindCompatible[V, F]`. The generic integration test
exercises these public contracts through source and precompiled imports.
Concrete families that use the defaults keep their existing behavior.

Result's carrier evidence remains exact nominal equality,
`V == Result[ResultFamily[E].Element[V], E]`. Generic outcome forwarders can
already provide that proof. Adding a separate `conforms_to(V, _ResultType)`
premise would require redundant evidence that Mojo 1.2 cannot always derive
from the equality during overload selection. Bind retains its existing guard
for a callback result that may be a different kind of carrier.

The shared carrier compatibility predicate also uses mapping admission, so
higher operations keep the same diagnostic origin. Like other dictionary
primitives, static family methods implement these preconditions over
already-admitted types: Mojo 1.1 does not support `where` on trait requirements.
Call the checked free functions or fluent methods at user input boundaries.

Generic native forwarders name the callback's raised type with `X=X`.
Admission extracts diagnostic and payload types separately instead of
reconstructing nested carrier types through callback metadata: Mojo cannot
reliably reduce those expressions through a precompiled package. The generic
integration test exercises mapping and binding through both import routes.

## Environment capabilities

`fp.effects.Ask` and `Local` are dictionaries separate from Monad and from the
private representation markers (`_ReaderFamily`, `_StateFamily`, `_WriterFamily`).
A dictionary associates a `Family` with a selected `Environment` and describes
its operations through exact carrier/error aliases. ReaderT is the direct
instance. Explicit `LiftAsk` and `LiftLocal` dictionaries name each intervening
layer, so equal environment types never make selection ambiguous. Third-party
code can implement the public capability traits without implementing a Reader
representation.

There is one read kernel and one environment-changing kernel, owned by Reader.
Ask lifting calls the selected read and the layer's existing `lift`. Scope
transport follows each representation:

| Layer | Transport of the selected base scope |
|---|---|
| ReaderT | Run the outer action, then scope the resulting base carrier, retaining its outer origin parameter |
| StateT | Run the action with its owned state, then scope the resulting base carrier |
| WriterT | Scope its existing base storage and rewrap it, retaining log and payload |
| OptionalT / ResultT | Delegate on the base carrier; the inner sum remains unchanged |

These adapters neither interpret a stack nor reproduce Reader evaluation,
State threading, Writer accumulation or sum short-circuiting. Native construction
errors are combined only when their exact types are compatible; deferred errors
remain on `run`. The direct Reader entry points keep their existing names and
native callback overloads.

Admission belongs in signatures. Reader's `LocalCompatible` checks exact family
and environment identity and verifies that both `Out[o]` and `Error[o]` are
independent of the run environment. Empty and universal native origin witnesses are substituted only for this
type-level check; no runtime value is assigned either origin. Using the
universal witness also detects unions with fixed origins, which can collapse
two finite witnesses to the same union.
Mojo 1.1 erases origin distinctions in body-level equality assertions, so the
older assertion in `_ReaderLocal.run` was insufficient to reject an escaping
deferred continuation. The public predicate now rejects it before construction.
Lifted Reader admission applies the selected base predicate under both outer
origin substitutions, preserving an outer borrow while scoping only the inner
environment. Generic callers forward the public admission predicates.

For pure environment transformations, identity scoping preserves observation,
nested scoping composes transformations in execution order, scoping a pure
value leaves its payload unchanged, and scoping ask reads the transformed
value. The enclosing environment is restored after success and native failure.
An effectful transformation can run or raise when the selected Reader runs;
these algebraic laws do not equate different callback side effects. Ownership
checks cover move-only environments/state, consuming captures, abandoned
computations and externally borrowed payload/error types. Rejection fixtures
cover wrong layers, mismatched origins, consumed values and temporary-environment
escapes.

## State capabilities

`Stateful` follows the same explicit dictionary selection as Ask/Local. It
associates a Monad family with one exact state type, a read operation, and a
consuming state-to-state modification operation. StateT is the direct instance;
`LiftStateful` selects a capability belonging to the immediate base. Selection
does not search by state type or collapse adjacent State layers.

State owns the existing `_StateGet` and `_StateModify` execution kernels.
The public `get`, `modify` and `put` entry points live in capabilities; their
original imports from the state module remain available. StateT's dictionary
methods construct those same kernels. `put` delegates to `modify` with an
owned replacement callback. Each lifted primitive invokes the base capability
and the transformer's existing lift; it needs no additional representation
adapters, state-threading loop or carrier. Native lift-error propagation shares
the adapter used by Ask lifting.

`GetAvailable` admits copying the selected state. `ModifyCompatible[F]` admits
the exact callback state types and, for lifting, the selected base family and
compatible native construction errors. Public modification signatures also
require exact Arg/Out identity with StateType; body assertions alone cannot
protect embedded origins on Mojo 1.1. `Got`/`GetError` and
`Modified[F]`/`ModifyError[F]` distinguish construction from deferred execution.
Generic forwarders propagate these aliases and admission constraints. A native
callback overload only adapts the native signature to the shared consuming
callback contract.

For pure, terminating updates: get leaves the state unchanged; get followed by
putting the same value is observationally neutral; put followed by get observes
the replacement; the last of two puts wins; identity modification is neutral;
successive modifications compose in execution order. These laws compare values,
not callback side effects or destruction traces. They inherit each stack's
stored-failure and branching semantics. Native exceptions do not become stored
errors and there is no transactional rollback.

Qualification covers direct and lifted reads/updates through all five layers,
nested selection, identical state types, generic third-party dictionaries,
stored-error stack order, construction versus execution errors, move-only
states/captures, exact borrowed state/error types and abandoned computations.
Rejection fixtures cover wrong bases, missing generic admission, wrong callback
types/origins and reuse after consumption.

## Writer capabilities and shared carrier transport

Tell, Listen and Censor are public dictionaries independent of the Writer
representation. WriterT provides the direct instance. LiftTell uses the existing
base write and transformer lift, sharing native lift-error propagation with
Ask and Stateful. LiftListen and LiftCensor explicitly transport the selected
base operation through the destination layer. Equal monoids do not collapse
adjacent Writer layers.

Writer remains the owner of log execution: tell constructs its base pair,
listen uses `_Listen` to copy and expose the log, and censor uses `_Censor` to
consume and replace it. The checked free functions live in capabilities and
delegate to those primitives. Public signatures check exact carrier and log
origins, rather than relying on body assertions.

Local, Listen and Censor share `_CarrierOp` and `_Hoisting`. The operation names
its exact input admission, output carrier and native error; each representation
owns reaching and rewrapping its base. Reader and State each have one deferred
transport kernel that runs the source then applies the base operation. Reader
retains its origin parameter on both results and errors. Writer unwraps and
rewraps its storage; OptionalT and ResultT already are base carriers. This
replaces the earlier Local-specific deferred wrappers without changing Local's
temporary-environment lifetime admission.

Listening additionally rearranges the observed log beside the logical payload:

| Layer | Base observation | Repacked base payload |
|---|---|---|
| ReaderT | `(A, L)` | `(A, L)` |
| StateT | `((A, S), L)` | `((A, L), S)` |
| WriterT | `((W, A), L)` | `(W, (A, L))` |
| OptionalT | `(Optional[A], L)` | `Optional[(A, L)]` |
| ResultT | `(Result[A, E], L)` | `Result[(A, L), E]` |

Pair rearrangement shares the native consuming-pair helper. Sum rearrangement
uses the existing Optional/Result map operations and the owned second-value
pairing callback already used by State lifting. The callback now lives with the
shared callable product operations; State retains its private import alias.
No transformation copies a payload or context. The one observed-log copy is
moved into success or dropped on absence/failure, leaving the output log intact.

Mojo 1.1 does not reliably reduce `Element[Listened[V]]` within generic
admission. The mapped-listen adapter instead checks the original payload type
and the exact `(payload, log)` callback input separately. Listen's public
contract supplies that pair, and the ordinary family mapping admission and
native error compatibility checks still apply. This uses no runtime origin
substitution. Reader transport checks admission under empty and universal
origin witnesses and retains the actual origin when running.

For lawful monoids and pure, terminating callbacks, consecutive tells append in
order, listening preserves the output log, identity censor is neutral, and
nested censors compose in execution order. Scopes affect only their argument.
These laws compare values, not native side effects, destruction traces or
exceptions. Stack order still decides whether a stored failure retains output.
Qualification covers all five layers, nested and same-monoid selection, external
dictionaries, generic forwarding, native error phases, copy counts, move-only
logs/payloads/state/captures, borrowed origins and rejected invalid selections.

## Absence fallback inside a base effect

`or_else_absent[Base](factory, source)` consumes a base carrier of `Optional[A]`.
The present branch moves its payload through the base's `pure`; the absent
branch invokes the factory and uses its base carrier of `Optional[A]`.
`get_or_else_effect` uses the same branch owner but removes the Optional layer:
its factory and final result carry `A` in the base.

Selection names the **base** family. For a native Optional, select
`IdentityFamily`; for `OptionalT[State[S]]`, select `State[S]`. This preserves
the existing meaning of stored-error recovery through `OptionalT`: absence is
a separate condition, and base failures never trigger an absence factory.

The existing Optional choice kernel owns branch selection, and base bind owns
evaluation, branching and deferred execution. A factory is consumed at most
once by a linear base. A branching base requires a repeatable factory and calls
it once for each absent branch; results are not cached across branches.
Skipped factories and discarded sources release their owned captures. Earlier
state changes and Writer output remain visible; external effects are never
rolled back. Native errors stay raised with their exact type and normal timing.

`AbsenceContract[Base, V, F, keep_optional]` supplies the public `Compatible`,
`Out` and `Error` projections for forwarding library callbacks. It checks the
exact Optional payload, fallback carrier, join and callback receiver. Different
concrete deferred carriers may join without boxing or erasing origins.

## Step-driven effectful loops

`tail_rec_m[Family](step, initial)` repeats a step from `A` to a family carrier
of `ControlFlow[B, A]`. `Continue[A]` moves the next state into another step;
`Break[B]` supplies the final result. A failed or absent effect stops its branch
without another step. List keeps its ordinary branch order and copying rules.
Construction and execution remain separate for Reader and State, including
when the step reads an environment or updates state.

The implementation supplies an unbounded unit source, a Continue liveness
policy and a step adapter to the existing dependent fold. The native while
loop remains its execution owner. The unit source is necessary because native
`repeat` requires a finite count. Neither a trampoline nor recursive callback
composition is added. Stack usage is constant in the number of steps for the
built-in families; state, logs and branching results can still grow. Custom
families must implement a stack-safe dependent fold to satisfy that guarantee.
An always-continuing computation does not terminate automatically.

`TailRecContract[Family, F]` infers the Break payload and supplies `Compatible`,
`Out` and `Error`. The state must exactly equal the callback argument, including
origins; the callback must be repeatable. Existing fold admission still applies
to transformer order and base carriers. Failures destroy owned state and
callback captures, with native errors distinct from the effect's stored errors.

## Borrowed environment and state projections

`Project` is a compile-time capability independent of `Ask` and `Stateful`.
It selects an `Input` and `Family` and provides a borrowing projection returning
a carrier of the callback's owned result. Reader and State implement it for
their own environment and state. `asks` and `inspect` are environment- and
state-oriented spellings of this one capability; `LiftProject[Layer, Capability]`
selects it through an immediate base layer. This does not add requirements to
existing user implementations of Ask or Stateful.

Projections are deferred, consume their callback and run it exactly once at the
selected read boundary. They need no copy of the environment or state and
support `BorrowOnceCallable` captures. Reader borrows its run environment;
State ends the projection borrow before moving the unchanged state into its
base carrier. These distinct native run signatures delegate invocation to the
same borrowing-call owner. The result or error cannot retain a borrow into a
temporary run input. Independently captured owners keep their exact origins.

`ProjectCompatible[F]`, `Projected[F]` and `ProjectError[F]` describe admission,
result and construction error. Reader and State construction is non-raising;
the callback's exact error belongs to execution. Lifting retains the layer's
usual construction errors and execution timing, including Writer identity
construction. Dropping an unopened recipe drops its captures without invoking
the projection. Copying a recipe requires copyable stored callbacks.

## Resource and IO execution contract

Resource recipes are inert, consumed descriptions of synchronous native
acquisition and release. `resource[E](acquire, release)` selects one exact
native error type; callbacks may raise E or Never. Different error types require
an explicit common mapping. `use` borrows the acquired value and returns an
owned result in `Result[A, EffectFailure[E]]`. The result and error cannot borrow
the acquired value. Independent captured origins remain available.

Acquisition failure skips use and release. After successful acquisition, release
runs exactly once after use, including a failed use. Both failures are retained
in order in a non-empty collection, without stringifying or copying errors.
Product acquires left then right and releases right then left. Flat-map borrows
the outer value to construct an independent inner recipe; failed construction or
inner acquisition releases the outer value. It does not build self-referential
resources borrowing their enclosing lease. Unopened recipes only destroy their
stored callback owners. Fallible release belongs to this explicit runner, never
to a destructor.

IO is a selected Reader family over ResultT and Optional. Its context contains a
shared cancellation token and a local masking flag. Native exceptions are
captured through the existing one-shot Result boundary; algebraic map, bind,
error recovery and loops retain their existing execution owners. Cancellation
is the absent outer Optional, separate from a stored error. `EffectFailure`
retains a non-empty sequence of exact errors and whether cancellation also
occurred. All runs consume their concrete program type and preserve its captured
origins; no callback erasure or interpreter registry is introduced.

Delay runs a native callback once at execution. Cooperative cancellation is
observed before and after native operations and while waiting; arbitrary native
code is not preempted. Side effects already performed are not rolled back.
Guarantee runs its finalizer once after an entered body, with cancellation
masked, preserving both body and cleanup failures. A request received while
masked is observed when the surrounding unmasked operation resumes. Programs
whose finalizer never terminates cannot finish cancellation.

`use_resource` defers one complete synchronous resource scope into IO. It checks
cancellation before entry and after release. Its native callbacks are synchronous;
a cancellation request cannot skip release or interrupt acquisition midway.
As with delay, a long native callback must return before this boundary observes
cancellation. General IO finalizers are composed with guarantee. This bridge
retains native callback signatures; IOResource supplies the effectful lifecycle.

Shared callable adapters own invocation conventions, Result capture owns native
exception conversion, and one outcome combiner owns finalization precedence.
Resource code owns lifecycle transitions; IO code owns cancellation checkpoints
and masking. Runtime threads and coordination will be separate consumers of
these contracts, with their host and threading requirements documented explicitly.

The IO kernel lives in `_io_core`, with the existing `effects.io` imports
retained as a facade. `finalization` owns one entered-body runner shared by
`guarantee`, `guarantee_case` and `on_cancel`. It splits the body outcome into
an owned success slot and an `ExitCase`, borrows the case during cleanup, then
reconstructs the original outcome before the existing `_finish` combiner merges
cleanup. No success or error payload must be copyable. `on_cancel` observes
cancellation on the completed body; a request first observed after that point
does not retroactively select its cleanup.

`ScopedIO` separates a factory's temporary input origin from its completed
result and error. The constructed `Action[o]` can retain that borrow only until
the scoped runner consumes the action. The runner captures factory exceptions
and action exceptions through the same Result boundary used by delay. Fixed
native return types use `scoped_io`; custom origin-dependent factories implement
the protocol directly. Neither path erases captured origins.

Every cancellation mask has an owned identity marker. `uncancelable_with`
constructs a `Poll` carrying the previous context and the marker of its region.
Applying a poll restores the previous context only when that marker is current.
A nested mask or finalizer has another marker, so an outer poll cannot remove
its protection. Restoring an enclosing mask keeps cancellation masked. Keeping
a poll after the region ends keeps its marker alive, prevents identity reuse,
and cannot unmask unrelated later work. Mask exits and completed finalization
settle pending cancellation before an ordinary monadic continuation can run.
This supports cancellation semantics
without depending on private Mojo coroutine APIs; execution remains synchronous.

General algebra operations preserve native callback error timing. A raising
callback in `map` or `flat_map` therefore has a native error channel until an IO
capture boundary. `capture_io(program)` places that boundary before stored-error
recovery, so `IO[E].or_else(handler, capture_io(program))` can recover it. Delay,
guarantee, resource execution and host runs already capture their protected
native calls. Cancellation remains separate from this error recovery.

## Fibers and shared coordination

The optional fiber backend starts one OS thread per IO recipe using the public
Mojo `std.ffi` interface to POSIX `pthread_create` and `pthread_join`. Its current
contract is 64-bit Linux; other targets reject `unsafe_start` before opening the
program. It is deliberately separate from the portable synchronous IO boundary.
This is an explicit exception to the no-FFI core principle, not a compiler or
standard-library modification. Mojo's unfinished native async types are not used.

`unsafe_start(program)` transfers the complete concrete program type into an
ArcPointer allocation. A specialized C-ABI entry point receives a typed pointer;
there is no erased closure registry or origin cast. The owner retains that stable
allocation until a successful join. The destructor explicitly consumes that
owner after joining: Mojo may otherwise destroy an unused field before entering
the destructor body. Only the worker accesses the program and
result before join; completion and cancellation use atomics. A failed thread
creation destroys the unopened program. A failed join aborts rather than freeing
state which a worker might still use.

Mojo has no Send/Sync proof. The caller must ensure every captured value,
callback and destructor is safe on the worker thread, all referenced owners stay
valid until join, and concurrent mutation is synchronized. Preserving the
concrete type does not establish thread safety. In particular, accepting a
native mutable capture does not prove exclusive access across threads.
`unsafe_start` marks this obligation explicitly.

A Fiber owns its join obligation. `request_cancel` only signals;
`join` waits and transfers the outcome; `cancel` signals and joins. Destruction
signals and joins too, then discards the outcome. `join_io` defers an owned join:
a cancellation observed after entry signals the child, waits for its finalizers,
and retains child errors with the cancellation flag. An unopened join dropped
or skipped by an already-canceled outer run still destroys and joins its owned
Fiber, but does not expose its discarded errors. Cancellation remains cooperative:
unresponsive native code, masked waits or finalizers can block joining forever.
This backend provides OS-thread concurrency, not lightweight scheduling.

Ref is the single owner of shared-state synchronization. Its ArcPointer cell
contains an atomic mutex and an owned optional slot. A guard releases the lock;
all state accesses derive through that guard. `modify[E, A]` consumes T and
returns `(T, A)` without raising, so failure cannot lose consumed state. `inspect`
borrows T and captures exact native errors; outputs cannot borrow the temporary
cell access. `get`, `update`, `set` and `get_and_set` derive from these two drivers.
Native signatures infer their input and result independently before exact type
checks. The explicit A avoids a Mojo 1.2 nested-tuple inference crash without
weakening the result contract.

The guard is destroyed before cancellation settles a returned value: that
value's destructor may itself access the Ref. Callbacks and replaced state
owners' destructors still execute under the lock and must not reenter that
same cell. Lock contention sleeps between cancellation checks; no fairness or
lock-free progress is promised. Updates already completed survive cancellation.

Deferred uses `Ref[Optional[T]]` for a single winning completion. Readers copy
T, so this primitive requires Copyable payloads. Semaphore uses `Ref[Int]` and
returns a move-only Permit. Destroying a permit performs a masked increment
through the same Ref driver; cancellation after reservation therefore restores
the count. `with_permit` derives from existing flat_map and guarantee, including
unopened owner destruction, without another lifecycle runner.

Queue uses `Ref[std.collections.Deque[T]]` for bounded FIFO transfer, including
move-only T. A full `try_offer` returns the rejected owner; `offer` retains it
across retries. `try_take` transfers the head, while `take` waits. A common
optional-result polling driver serves Deferred, Semaphore and Queue reads.
Queue writes need an owned retry state because their rejected payload cannot
be copied. All retries release the lock before sleeping and observing
cancellation. Accepted enqueues and completed dequeues are not rolled back;
a canceled, unobserved dequeued owner is destroyed exactly once.


Effectful resources reuse the native resource engine. `_OpenScope.open` receives
an exact execution context and returns an Outcome of a registered lease;
`_Lease.close` carries the completed body outcome through release. Native `use`
passes a unit context and allocates no IO token or mask. IOResource passes its
IOContext. Product, dependent acquisition, owned projections, rollback and
reverse release order have one implementation. Right release completes before
left release receives its exit case, including right cleanup errors.

Default effectful acquisition runs masked and converts success into a lease
before returning to the enclosing cancellation state. Full acquisition uses the
same masked factory runner as `uncancelable_with`, but registers its lease before
settling pending cancellation. Settling first would destroy a successfully
acquired value without invoking its registered cleanup. Cancellable waiting is
explicitly selected by Poll; failed partial acquisition owns its own cleanup.

Release delegates to `_finalize_outcome`, also used by IO guarantee operations.
An owned resource and its consuming release factory become a scoped finalizer;
its two construction stages share canonical callable invocation and exact error
propagation. A non-throwing whole-owner handoff precedes fallible construction,
so Mojo does not need to unwind a partially consumed receiver. Ordinary release
normalizes its returned IO into a constant scoped factory. Case-aware release
already returns a ScopedIO over ExitCase. No lifecycle driver or native callback
ABI implementation is duplicated.

Effectful use and projections run with the resource borrowed until their action
completes. Success values and errors are independent of that fresh origin;
callbacks and actions keep all independent capture origins. This supports
move-only resources and failures without self-referential leases. Resource
semantics currently execute on synchronous IO; a future suspension backend must
preserve these acquisition handoff, masking and finalization boundaries.
