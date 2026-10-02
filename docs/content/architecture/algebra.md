# Algebra and effects

`fp.algebra` defines five small interfaces with native instances; `fp.effects`
builds Reader, State and Writer computations and the OptionalT, ResultT, ReaderT,
StateT and WriterT transformers on them. Mojo owns control flow, storage,
ownership, origins, calls and exceptions. The library adds no runtime dictionary
registry, erased action box, interpreter or parallel storage hierarchy.

## Scope

| Kind | Members |
|---|---|
| Interfaces | `Functor` (`map`), `Applicative` (`pure`, `map2_lazy`), `Monad` (`flat_map`), `Traversable` (`traverse`), `Monoid` (`empty`, `combine`) |
| Derived operations | `map2`, `ap`, `flatten`, `sequence`, defined once over the interfaces |
| Native instances | `IdentityFamily` (a bare value), `OptionalFamily`, `ResultFamily[E]`, `ListFamily`, using the standard carriers |
| Monoids | `StringMonoid`, `ListMonoid[A]` |
| Transformers | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`; `Reader`, `State` and `Writer` are these over `IdentityFamily` |

An instance is a compile-time dictionary: a type whose operations are static
methods and whose result and error types are associated aliases. The public free
functions forward to it, and the caller selects it explicitly:
`map[OptionalFamily](f, value^)`. List's applicative combination is Cartesian in
left-major order.

## Design rules

1. **Behavior in methods; types by local alias.** Each result and error type is
   an associated alias (`Mapped[V, F]`, `MapError[V, F]`, ...) that names only
   the instance's own parameters and their immediate associated types (`F.Out`,
   `F.Error`, `S.Out`). No dictionary member names an executor, a run selector or
   a conditional chain over other dictionaries, so naming a family costs no
   type-level evaluation. Method bodies are elaborated only for concrete uses.
2. **One struct per operation.** A deferred computation is a concrete struct
   that stores its inputs and runs itself: Reader has `_ReaderPure`,
   `_ReaderMap`, `_ReaderBind`, `_ReaderAsk`, `_ReaderLocal`, `_ReaderLift`,
   `_ReaderLoop` and `_ReaderChoice`, and State has the corresponding
   `_State*` structs plus `_StateGet` and `_StateModify`. A composed
   computation's type is the tree of its operations. There are no plan tags,
   recipe tables or descriptor indirection.
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
5. **Separate types instead of flags.** Each transformer is its own struct, and
   each native family owns its methods; nothing switches on a tag.
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
cost was in the type-level program (parameter verification and inlining), not in
code generation, and a warm compile cache hid it completely.

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
- State owns one loop: probe the base carrier for a live branch, pull one item,
  call the producer once and bind the prepared computation across the live
  branches, each with its own state. The base carrier must keep one type, so a
  deferred base under State traversal is rejected at compile time.
- OptionalT, ResultT and WriterT wrap the policy (absent or failed accumulators
  stop; logs combine in order) and delegate to their base's `_loop`, so pull and
  producer counts are the same over eager, deferred and third-party bases.

A deferred traversal is one concrete loop computation, never a chain of
computations that grows at run time.

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
