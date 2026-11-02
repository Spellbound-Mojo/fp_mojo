# Support and limitations

This page lists supported platforms and the limits that affect how you call the
library. For each restricted form, the table describes what works today.
[Native Mojo boundaries](../architecture/native-boundaries.md) explains the
compiler constraints behind these choices.

## Platforms

| Item | Status |
|---|---|
| Compiler | Mojo 1.2.0, pinned through Pixi; FP Mojo 1.0.2 requires it. FP Mojo 1.0.0 and 1.0.1 require Mojo 1.1.0 |
| Linux x86-64 | Full library support: positive and rejection test suites, precompiled packages, and the multi-threaded work-stealing async runtime. |
| macOS arm64 | Full library support: positive and rejection test suites, precompiled packages, and the multi-threaded work-stealing async runtime. |

The [compatibility guide](compatibility.md) documents API migration and
operational contracts between Mojo versions.

## Combinator support

The table below records the implemented combinator groups.

These combinators remove wrapper lambdas from container and Result chains.
Capability operations own execution; fluent methods delegate to them. Native
origins, callback receiver modes and the distinction between stored and raised
errors remain part of every operation's contract.

| Group | Scope | Status |
|---|---|---|
| 1 | Fluent `map2` and `product` on Pipeline, including Result carriers | Implemented |
| 2 | `traverse_void` and `traverse_tap` for container and iterator pipelines | Implemented for the [documented source families](../reference/combinators.md#containers-and-capabilities) |
| 3 | Selective recovery (`recover_if`, `or_else_if`), effectful error observation (`flat_tap_err`) | Implemented on Result and Pipeline |
| 4 | `map_both`, `redeem`, `redeem_with`, whole-outcome observation (`attempt_tap`) | Implemented on Result and Pipeline |
| 5 | `sequence_void`, `flat_traverse`, `flat_sequence`, `filter_effect` and `traverse_filter` | Implemented for the [documented source families](../reference/combinators.md#containers-and-capabilities) |
| 6 | Effectful folds and predicates (`fold_effect`, `any_effect`, `all_effect`), conditional composition (`if_effect`) | Implemented; see [effectful reductions](../reference/combinators.md#fold-and-choose-effects) |
| 7 | Fluent `ap`, multi-argument mapping and tuple construction | Implemented as `ap`, `map_n` and `product_n`; see [combination contracts](../reference/combinators.md#combine-and-inspect-effects) |
| 8 | Kleisli composition of functions returning an effect | Implemented; shared composition engine and automatic `.map(chain)` adaptation |
| 9 | Parallel validation with error accumulation, `par_map_n` and `par_traverse` | Implemented; type-preserving Result accumulation through Semigroup |
| 10 | Parallel products and sequencing, `par_product_n` and `par_sequence` | Implemented through the existing n-ary runner and identity traversal |
| 11 | Monad and iterator sequencing, `flat_tap`, `followed_by` and `before` | Implemented through shared retention and the existing map/bind operations |
| 12 | Effectful pairing, `flat_pair_with`, across Monad families and Iter | Implemented through the existing paired retention mode |
| 13 | Shared stored-error capability and generic `recover`/`or_else` | Implemented for ResultFamily, ValidationFamily and ResultT |
| 14 | Lift error recovery through ReaderT, WriterT, OptionalT and StateT | Implemented; [transformer recovery contracts](../architecture/algebra.md#shared-error-handling) |
| 15 | Shared conditional recovery (`recover_if`, `or_else_if`) | Implemented through ApplicativeError |
| 16 | Shared error observation (`tap_err`, `flat_tap_err`) | Implemented through ApplicativeError |
| 17 | Shared success validation (`ensure`) | Implemented through Monad and ApplicativeError |
| 18 | Shared outcome composition (`redeem`, `redeem_with`, `attempt_tap`) | Implemented with a fixed stored-error type |

The library enforces an acyclic layering architecture across all modules.
Algebra conveniences on `Result` operate through `pipeline(result^)`.
`NonEmptyList`, its concatenation `Semigroup`, and shape-preserving families are
fully supported (see [non-empty validation](../reference/data.md#non-empty-collections-and-validation)).
Computations producing values alongside non-fatal warnings are modeled via `Ior`
with sequential and accumulating families (see [inclusive-or](../reference/data.md#success-with-warnings)).

Type-level capabilities (Cats MTL pattern) decouple effectful operations from concrete
monad transformer stacks:
- Environment access: `Ask` and `Local` (see [environment capabilities](../reference/effects.md#program-against-environment-capabilities)).
- State transitions: `Stateful` (see [selected state capabilities](../reference/effects.md#program-against-a-selected-state)).
- Logging: `Tell`, `Listen`, and `Censor` (see [selected log capabilities](../reference/effects.md#program-against-a-selected-log)).

Iterator capabilities include fluent method chaining, consuming terminals,
lazy partitioning with explicit buffering policies, multi-stream alignment, scans,
and effectful searches (see [iterator architecture](../architecture/iteration.md)).

Combinator operations are unified across supported capability families. Shared
operations derive from fundamental family primitives rather than requiring
separate implementations for each container.

### Applicative combination and multi-argument mapping

- **Cartesian and independent combinations (`map2`, `map_n`, `product_n`, `ap`)**:
  Combine independent computations without nested callbacks. In `Pipeline`, the
  receiver is the first operand, and products yield flat tuples.
- **Collection behavior**: `List` combination is Cartesian in left-major order
  and requires copyable elements. `Optional` and `Result` combine at most once,
  admitting move-only payloads and short-circuiting on the first error or absent
  value.
- **Native signatures**: Native callbacks admit one to eight arguments. Variadic
  combinations support inferred `List`, `Optional`, and `Result` carriers;
  explicit family parameters support up to eight operands.

### Traversal and sequencing

- **Collection traversal (`traverse`, `sequence`)**: Applies an effectful callback
  to each element and gathers the results into the target effect (`List`, `Optional`,
  `Result`, or `IO`). Execution stops at the first failure or absent result.
- **Effectful observation and side-effects (`traverse_tap`, `traverse_void`)**:
  `traverse_tap` executes an effect for each element while retaining the original
  input values and source shape. `traverse_void` evaluates each element's effect
  for side effects and discards intermediate results without allocating an output
  collection. For `Result` sources, a source error is preserved as an inner
  `Result[NoneType, E]` in the target effect, keeping source errors distinct
  from target-effect failures.
- **Monadic flattening during traversal (`flat_traverse`, `flat_sequence`, `traverse_filter`)**:
  `flat_traverse` combines element traversal with monadic flattening.
  `traverse_filter` filters elements using an effectful predicate, discarding
  absent values without intermediate list construction.

### Error handling, observation, and recovery

- **Selective error recovery (`recover_if`, `or_else_if`)**:
  Inspect stored errors using a predicate. Matching errors are passed to the
  recovery callback to produce a replacement value or fallback; non-matching errors
  pass through unchanged.
- **Error observation (`tap_err`, `flat_tap_err`)**:
  Observe stored errors without modifying successful outcomes. `tap_err` runs a
  side-effecting callback on failure, while `flat_tap_err` chains an effectful
  observer. If the observer fails, its failure replaces the original error; if it
  succeeds, the original error is retained.
- **Outcome mapping and branch handling (`map_both`, `redeem`, `redeem_with`, `attempt_tap`)**:
  `map_both` transforms both success and error payloads simultaneously. `redeem`
  maps both success and error branches into a common result type, wrapping the
  outcome in `Ok`. `redeem_with` branches into a new `Result` or effect for each
  case. `attempt_tap` inspects the complete outcome (`Ok` or `Err`) in place,
  continuing on observer success.
- **Success validation (`ensure`)**:
  Validates a successful payload with a predicate, converting rejected values into
  a typed error while leaving existing failures untouched.
- **Generic error handling via `ApplicativeError`**:
  Unifies error construction (`fail`) and recovery (`recover`, `or_else`) across
  `ResultFamily`, `ValidationFamily`, and `ResultT`.

### Parallel validation and concurrent collections

- **Parallel validation (`par_map_n`, `par_product_n`, `par_traverse`, `par_sequence`)**:
  Under `ValidationFamily`, combines independent results without short-circuiting
  on the first failure. List-valued errors concatenate by default, and custom error
  types combine via an explicit `Semigroup`. Native raised errors stop execution
  immediately, preserving the distinction between synchronous native exceptions
  and accumulated domain errors.
- **Concurrent collection execution (`IO` & `AsyncPar`)**:
  Under the async runtime, parallel combinators run each element concurrently as a
  lightweight child fiber using `AsyncPar[E]`. Supports unbounded concurrency
  (`par_traverse`, `par_sequence`, `par_traverse_void`) and bounded concurrency
  pools (`par_traverse_n`, `par_sequence_n`, `par_traverse_void_n`). See
  [concurrent collections](async-runtime.md#run-a-collection-concurrently).

### Monad sequencing, pairing, and composition

- **Chaining and sequencing (`flat_tap`, `followed_by`, `before`)**:
  Sequence dependent operations across Monad families and lazy iterators (`Iter`).
  `flat_tap` runs a dependent effect and returns the original value. `followed_by`
  sequences two steps and keeps the second; `before` keeps the first.
- **Effectful pairing (`flat_pair_with`)**:
  Projects an effect from each value and yields an `(original, projected)` pair
  per successful branch.
- **Function and effect composition (`kleisli`, `flow`, `compose`, `contramap`)**:
  Compose functions returning effects with `kleisli[Family](f).then(g).map(h)`.
  Reverse composition is supported with `compose`, and input adaptation with
  `contramap`.
- **Effectful conditionals (`if_effect`)**:
  Evaluates an effectful boolean condition and branches into one of two lazy
  computation factories without evaluating both.

### Monad transformers and effect capabilities

- **Transformer error lifting**:
  `ApplicativeError` capabilities lift transparently through `ReaderT`, `WriterT`,
  `OptionalT`, and `StateT` when their underlying base Monad supports error handling.
- **State and log preservation**:
  `StateT` recovery restores the input state at the recovery boundary. `ResultT`
  layered above `State` retains updated state through failures and admits move-only
  state types. `ReaderT` preserves the borrowed environment, `WriterT` retains
  the handler's log on failure, and `OptionalT` preserves absence. See
  [shared outcomes](../reference/combinators.md#validate-and-observe-outcomes).

The source references are Cats' [Apply](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Apply.scala),
[Traverse](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Traverse.scala),
[error handling](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/ApplicativeError.scala),
[Kleisli](https://typelevel.org/cats/datatypes/kleisli.html) and
[Parallel](https://typelevel.org/cats/typeclasses/parallel.html).

## Known boundaries

| Area | Current behavior |
|---|---|
| Partial application | `partial` binds a positional prefix of up to eight arguments of a plain function. It does not bind keywords, reorder arguments, accept capturing targets, `mut` parameters or owned remaining parameters, or nest. A native closure expresses all of these. |
| Lazy iteration callbacks | They cannot raise; carry failures as `Result` elements. |
| Match clauses | `fp.match` and `fp.rewrite` take one to sixteen clauses: plain functions or lambdas without captures. Data a clause needs is passed with `context=` or as a component of a tuple of values. |
| Pipeline stages | `pipe`, `flow` and `compose` take two to eight plain functions directly. A closure is promoted with `as_unary`, and then every native function in that chain is promoted too. `pipeline(value).then(f)...get()` chains any number of plain functions, closures and library values; select a raising closure's error first with `.raising[E]()`. |
| `action` endpoints | `action` takes library endpoints (`BorrowCallable` for Reader, `Unary` for State): a plain function with read parameters would match both native forms. |
| Algebra and effect callbacks | `map`, `flat_map`, `traverse`, `modify`, `censor` and `local` take native functions or closures. Free `map2`, `map2_lazy` and `ap` take library values; fluent `map2` accepts native functions and closures too. |
| Capture | `Capture[E]` binds up to eight consumed positional operands, or up to three mixed read/mutable/consuming operands with an optional homogeneous native keyword pack, before callback admission. `Capture.stateful` owns explicit mutable state for repeated plain-function calls. Tested invalid calls diagnose without callback-type bindings. It replaces the removed `attempt`, `attempt_kwargs` and `attempt_once` functions and the `mutating`, `consuming`, `mut_owned` and `mut_owned_kwargs` adapters; other call shapes use a zero-argument closure. |
| Selected pipeline | `pipeline(value).raising[E]()` selects native errors once for family operations and Result combinators. Raising plain functions select their own error when none is selected; native closures use the selected error. The former `Piped` struct and `piped` factory were removed; Pipeline provides every operation they offered, and `pipeline_values` covers Dict and StringDict values. |
| Named or defaulted parameters | Pass a native function with named or defaulted parameters to library functions through a closure that spells the call. |
| Closures with owned mutable state | Unannotated native callbacks can lose updates at O3 on Mojo 1.2. Use the documented always-inline requirement, explicit mutable library callables or Capture.stateful. |
| Closures with embedded origins | Some closures that combine embedded origins with captured state fail to compile on Mojo 1.1; pass borrowed views as arguments instead. |
| Same-named types in several modules | Two modules of one program that define same-named types and spell the same function type over them fail to compile on Mojo 1.1 (`invalid redefinition of 'def(...)'`); give those types distinct names ([details](../architecture/native-boundaries.md#known-compiler-defects)). |
| Generic wrappers | Selected native calls fix their error with `raising[E]()`. Generic family wrappers retain public admission predicates in their signatures, including carrier and error origins. Legacy native forwarders retain their documented explicit error bindings. |
| Match ownership | Matches borrow their subject and return values, never references into it; consuming access belongs to the types (`Result.fold_owned`, `Choice.unwrap`, `Optional.take`). |
| Guards and coverage | A guard is opaque to coverage: a guarded clause never covers a constructor alone. |
| Match size | Sixteen clauses per match and three subjects; clauses do not capture, so data they need comes through `context=` or a subject. |
| Native `Variant` | A native `Variant` is not a match subject; declare the type with `Data` and store it in a `Choice`. The [matching limits](../architecture/matching.md#limits) give the full list. |
| `local` | `local` rejects a base whose result keeps the environment. |
| Deferred Reader and State callbacks | Compositions, traversals and effectful reductions borrow native callbacks until the computation runs; keep them alive and unmoved, or supply an owned library callback (`as_unary(f^)` for unary functions). |
| Running a raising deferred computation | Its error cannot propagate from a function declared with a plain `raises`; catch it with `try`/`except`, where it keeps its exact type. |
| State traversal | Requires a base whose carrier keeps one type across steps. |
| `pure` over `WriterT` | Requires a monoid whose `empty` does not raise. |

When a program runs into one of these boundaries,
[troubleshooting](troubleshooting.md) lists the compiler messages and what to
check for each.
