# API quality roadmap

The next development cycle makes common workflows easier to express while
preserving Mojo's ownership, origins and exact error types. Cats and Cats Effect
provide concrete examples of the desired composition. The implementation uses
the existing invocation, argument-storage, family and execution owners.

## Reference workflows from Cats and Cats Effect

The reference snapshots are [Cats b055e31](https://github.com/typelevel/cats/tree/b055e31caf3b4922432f5423585094c3b3116eb8)
and [Cats Effect de84c01](https://github.com/typelevel/cats-effect/tree/de84c01f76b2f42fcee9d43aba66c82992add103).
The Scala excerpts below come from their documentation, with REPL prompts
removed where present. Their linked pages supply the surrounding definitions.
These excerpts guide API design; the executable Mojo clients below are the
programs qualified in this repository.

Cats' [Traverse example](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/Traverse.scala#L43)
lets the callback select the target effect:

```scala
import cats.syntax.all._
def parseInt(s: String): Option[Int] = Either.catchOnly[NumberFormatException](s.toInt).toOption
List("1", "2", "3").traverse(parseInt)
List("1", "two", "3").traverse(parseInt)
```

The first call returns a present list; the second returns absence. FP Mojo's
[inferred traversal example](../tutorial/pipelines.md#gather-effects-without-family-annotations)
uses the same structure with typed Result failures. No target-family or
callback-type binding is needed for a native Optional, Result or List target.

Cats' [Parallel example](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/docs/typeclasses/parallel.md)
combines dependent parsing with independent validation:

```scala
def parsePerson(ageString: String, nameString: String) =
  for {
    age <- parse(ageString)
    person <- (validateName(nameString), validateAge(age)).parMapN(Person)
  } yield person
```

The design target is a local choice between stopping at the first failure and
accumulating independent failures. FP Mojo's Result validation preserves its
stored error type and selected Semigroup. Its `par_map_n` and `par_traverse`
express accumulation; they do not implicitly schedule work on multiple threads.

Cats Effect's [Resource example](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/docs/std/resource.md)
separates acquisition and release from use:

```scala
def file(name: String): Resource[IO, File] = Resource.make(openFile(name))(file => close(file))
```

That page composes three files and closes them in reverse acquisition order
after `use`, including failures. FP Mojo already has consumed resource scopes
and IO resources. Its [resource example](../reference/effects.md) is a baseline
for composition and cleanup, not a claim of Cats Effect runtime equivalence.
Cats Effect's cancellation masking, reusable IO descriptions and asynchronous
runtime must be compared separately with this library's consumed recipes,
exact typed outcomes and documented cooperative execution.

Additional reference contracts are Cats' [Functor replacement and pairing](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/Functor.scala),
[Either syntax](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/syntax/either.scala),
[effectful folding](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/Foldable.scala#L466),
[Kleisli composition](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/docs/datatypes/kleisli.md)
and Cats Effect's [execution concepts](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/docs/concepts.md).

## Baseline clients

The baseline production code and clients are at
[cfa1319](https://github.com/Spellbound-Mojo/fp_mojo/tree/cfa131950acf0fbfafc7eb2d9cf026c4a770107e).
These ten existing examples are the acceptance corpus. Caller selections below
record choices beyond ordinary function declarations and model types. A
semantic family/error choice is recorded separately from a compiler-only type
hint. None of these clients needs `F=type_of(callback)` or a comparable hint.

| Workflow and existing client | Caller choices and current friction | Behavior to preserve |
|---|---|---|
| [Result values](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/result_values.mojo) | Direct transformations need no family selection; one reusable Kleisli handler selects Identity. | Default factories are skipped on success; fill consumes its eager replacement; stored errors stay stored. |
| [Eager and lazy collections](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/combinators.mojo) | Typed List literals and Array `.elements()` select element semantics; the example introduces three API styles together. | Eager stages finish immediately; lazy terminals control pulling; named inputs move or copy explicitly. |
| [Inferred traversal](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/inferred_traversal.mojo) | Two List literals name String; target effects and callback types are inferred. | First failure stops Result traversal; sequencing retains the source's order and shape. |
| [Accumulating validation](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/parallel_validation.mojo) | A reusable Kleisli selects ResultFamily; the final pair display still uses private payload access. | Independent errors accumulate in order; ordinary Result bind remains short-circuiting. |
| [Effectful fold](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/inferred_fold.mojo) | Bind the accumulator, then run the step; the target effect is inferred. | The failing input stops the example after two calls; empty input preserves the accumulator. |
| [Callback reuse](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/callback_reuse.mojo) | Two named partials; shared uses need no adapters, explicit movement transfers ownership. | Partial's documented bound-value copies and lazy callback origins remain intact. |
| [Native capture](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/capture_arguments.mojo) | Select String once per capture; mixed arguments spell mutable, borrow, take and kwargs. | Arguments retain their native conventions; a captured failure does not roll back mutation. |
| [Reader configuration](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/effects_reader.mojo) | A named Reader family is repeated in map, ask, local and run. | Construction invokes no callback; local configuration leaves the original unchanged. |
| [Resource composition](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/resource_scopes.mojo) | Resource constructors select Error; use consumes the composed scope. | Acquire left then right, release right then left; outcome errors retain the library's aggregation policy. |
| [IO execution and finalization](https://github.com/Spellbound-Mojo/fp_mojo/blob/cfa131950acf0fbfafc7eb2d9cf026c4a770107e/docs/examples/io_execution.mojo) | IO/Error selections recur in free operations; outcome extraction distinguishes cancellation from stored failures. | Delay until run; finalize on completion and cancellation; preserve exact outcome channels. |

Ownership-sensitive tests complement these examples: counters detect unwanted
copies and repeated callbacks; drop ledgers check skipped and consumed values;
origin fixtures reject escaping views. An output-only example cannot establish
those properties. Existing rejection tests with explicit callback-type bindings
remain controls, not evidence of ordinary-call diagnostics.

The current [API selection guide](../start/choosing-api.md) gives a task-based
starting path. The introductory collection example now compares eager and lazy
chains, with free functions linked separately. The validation example formats
its pair through public Result folding. The pinned baseline above retains the
earlier examples so these reductions in required concepts and private access
can be reviewed.

Tuple attachment now follows the same receiver policy as replacement:
single-call mappings move the attachment, repeated mappings copy it. This
accepts move-only attachments in Optional, Result, Identity and compatible
deferred families without changing collection or iterator repetition. The
shared tuple callback owns pairing; its shared receiver copies the attachment
and delegates to its consuming receiver.

Direct Result attachment now needs neither a Pipeline wrapper nor a callback.
Generic attachment helpers can use `TupleLeftContract` and `TupleRightContract`
to forward admission, result, construction error and continuation family without
naming private adapters. Both additions use the same tuple callback and map
policy; they introduce no new execution mechanism.

Stateful native capture now participates in ordinary callback composition.
Its existing owner implements the mutable unary contract by delegating to
`run`, returning the captured Result with no native raise. The capture-context
example uses inferred traversal and retains the owner's updated state without
a user-written callable struct. Mapping keeps individual outcomes; traversal
stops on the first stored error. Lazy evaluation and native origin tracking
remain with the existing iterator and callback-reference implementations.

This native interoperation has a different evaluation contract from deferred
state programs. Cats' [State example](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/docs/datatypes/state.md)
builds `nextLong` and `nextBoolean` as instructions and runs them with an
initial seed. The library's existing State family is the corresponding starting
point for composing deferred state transitions.

Declared effect families now participate in the shared family selector used by
Pipeline, continuation and inferred target operations. Reader, State, Writer
and IO clients can omit repeated family bindings. Their common metadata lives
in algebra, so selection does not import effect implementations. The Family
member now requires Functor, rejecting invalid declarations before selection;
operation-specific capability and carrier checks remain with their owners.

The Reader, State and IO examples now map through `pipeline(recipe)` while
preserving deferred execution and their output. Whole-recipe transformations
use `then` or explicit Identity. Erased transformer layers retain explicit
selection: a Reader containing Result does not identify ResultT's policy.

Selected Reader, State and Writer pipelines now finish with `.run(...)`,
delegating to their existing execution or unwrapping owner. This removes
carrier extraction and a repeated family binding at the boundary. Reader
retains borrowed origins, State consumes its initial state, and Writer leaves
a deferred base unexecuted. Generic callers forward the existing family
admission predicates. The State example also uses `followed_by(get[State])`
to remove a callback whose only purpose was to ignore the previous result.

IO pipelines now compose finalization and execution without extracting and
rewrapping intermediate recipes. The corresponding Cats Effect
[syntax implementation](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/syntax/MonadCancelSyntax.scala)
delegates directly to its effect owner:

```scala
def guarantee(fin: F[Unit])(implicit F: MonadCancel[F, ?]): F[A] =
  F.guarantee(wrapped, fin)
```

Pipeline's `guarantee` and `on_cancel` similarly call the existing IO operations;
their shared finalizer-admission predicate lives with finalization. `run_io`
delegates to the existing host boundary, with an optional shared token.
Cancellation, cleanup order and exact outcomes retain their existing semantics.
Generic selection constraints remain visible in method signatures so Mojo can
prove them from public IO contracts. No callback-type hint or new execution
implementation is needed.

Context generation now shares one region inventory for source replacement and
documentation. Generated overloads receive generated documentation;
handwritten execution methods retain their own outcome and ownership contracts.
A tooling regression checks preservation and idempotence across every region.

Reader environment scoping and Writer log operations now stay in the selected
chain. Cats' [Reader implementation](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/data/package.scala)
expresses the same environment-to-environment scope through its Kleisli owner:

```scala
def local[A, R](f: R => R)(fa: Reader[R, A]): Reader[R, A] = Kleisli.local(f)(fa)
```

Pipeline's `local`, `listen` and `censor` delegate to the existing capability
operations. Their native and library callback signatures reuse the ordinary
context descriptors; execution is not regenerated. The Reader pricing example
no longer extracts and rewraps a recipe around `local`, and the Writer example
uses one `flat_map(...).listen().censor(...).run()` chain. Listening still copies
the log once when its base executes; censoring accepts move-only logs and
captures. Explicit lifted capabilities continue to select inner layers.

## Milestones and pass boundaries

| Order | Milestone | Completion criterion |
|---|---|---|
| 1 | Establish this corpus, upstream references, caller choices and compilation baseline; reconcile current documentation. | The baseline is reproducible and historical evidence is clearly separated from current guarantees. |
| 2 | Explain the preferred direct Result, Pipeline, Iter and Capture entry points through these workflows. | A newcomer can choose an entry point without first learning the compatibility APIs; examples use public operations. |
| 3 | Make ownership-aware attachment and pairing follow actual invocation count. | Single-call families move attached values; repeated families require copying; skipped values and deferred recipes clean up correctly. |
| 4 | Improve binding, stateful callbacks and composition through existing argument and receiver owners. | Common workflows avoid user-written callable structs; existing partial-copy semantics remain explicit. |
| 5 | Complete generic contracts where real forwarding clients expose gaps. | Output family, value, native error, origins and receiver admission remain available through public contracts. |
| 6 | Consolidate remaining operation and signature descriptions in the existing generators. | Each semantic rule has one owner; native inference boundaries retain the evidence they need. |
| 7 | Qualify the resulting API, measure costs and prepare migration decisions. | Supported calls and platforms have reproducible evidence; release and deprecation choices are explicit. |

Each pass starts with a concrete user example and its full ownership/error
contract, then changes the canonical owner and necessary thin entry points.
Focused runtime, ownership, rejection and documentation checks accompany the
change. Commit and push each completed pass to nightly, then continue with the
next dependency. Broader qualification occurs at milestone boundaries. CI is
outside this development sequence.

Measure annotations, adapter introductions, unnecessary copies, ordinary-call
diagnostics, independent semantic rules and cold compilation costs. Generated
line count alone is not a usability or architecture measure. Existing supported
positional bindings and legacy entry points remain intact during this work.

Compiler-sensitive designs are evaluated separately with valid and invalid
clients through source and packaged imports. A compiler crash is a failure;
adding callback-type hints does not turn it into an ordinary-call fix. Keep
exact types and origins instead of erasing them to make a prototype compile.

## Cold compilation baseline

These observations use the baseline commit above, Mojo 1.2.0 (2016d0cd), Linux
x86-64 on an AMD EPYC 9V74 host. Three rounds compiled and ran the three
clients below serially from source at O3, with one compiler thread and an empty
Mojo cache for every build. No other compiler jobs ran during measurement.
The harness bounds each build to 180 seconds and 4096 MiB. All nine runs
passed with unchanged inputs and clean audits.

| Client | Median build seconds (range) | Median peak RSS MiB (range) |
|---|---|---|
| `result_values` | 7.75 (7.66–8.37) | 268.4 (264.7–270.7) |
| `inferred_traversal` | 7.15 (7.01–7.16) | 266.1 (262.7–268.3) |
| `capture_arguments` | 5.26 (5.10–5.27) | 246.5 (242.7–247.6) |

This small source-import sample is a baseline, not a speedup or a package-build
claim. The other seven workflows have no cold measurements in this checkpoint.
Reports are retained in `.cache/api-roadmap/pass1/measure-{1,2,3}/report.json`.
Repeat the following three times, choosing a fresh output directory each time:

```sh
pixi run python scripts/measure_compilation.py \
  docs/examples/result_values.mojo \
  docs/examples/inferred_traversal.mojo \
  docs/examples/capture_arguments.mojo \
  --level 3 --threads 1 --output .cache/api-quality-measure-001
```

Later comparisons must use the same clients, compiler, target, limits and cache
policy, and report runtime/ownership equivalence alongside compilation cost.

## Milestone comparison

The checkpoint at [a89e752](https://github.com/Spellbound-Mojo/fp_mojo/tree/a89e7525dc0d8da7ed615bc853251c00ec134381)
qualifies the first sixteen passes. The complete source and precompiled-package
O3 suites each passed 1,029 non-benchmark programs and two diagnostic benchmarks.
All 2,716 rejection fixtures produced their declared diagnostics without crashes
through both import routes. The ten reference workflows passed all 40
source/package O0/O3 builds with exact
output checks. New ownership, generic-forwarding and invalid-call cases also
have focused source/package O0/O3 evidence from their implementation passes.

| Workflow | Change since the pinned baseline | Remaining distinction |
|---|---|---|
| Result values | Direct tuple attachment accepts move-only values; generic wrappers have public attachment contracts. | Repeating families still need copies. |
| Collections and validation | Introductory examples use a clear eager/lazy choice and public Result inspection. | Validation remains an explicit policy choice. |
| Capture | Stateful capture works as a mutable callback in mapping, traversal and lazy composition. | Mixed native argument conventions still need explicit binding; these examples retain that spelling. |
| Reader, State and Writer | Declared recipes infer their family; chains support execution, environment scoping and log operations. State sequences independent recipes with `product_r`; Writer appends logs with `tell` after an ordinary value callback. | Erased transformer layers need explicit selection; deferred native callbacks retain their origins. |
| IO | Finalization, outcome-aware cleanup and execution stay in one chain through the existing IO owners. | Consumed recipes and cooperative cancellation retain this library's execution contract. |
| Traversal, folds and resource composition | Declared target recipes share family inference. Resources support `use_void`, public generic scope metadata, and direct stored-pointer IO factories. | Lifecycle execution remains with the existing resource and scoped IO owners. |

The selected Pipeline inventory now covers every legacy Piped method name.
That is useful for discoverability, but does not make signatures, error
selection or ownership contracts mechanically interchangeable. Legacy controls
that need explicit callback-type hints remain documented limitations.

Three serial cold-build rounds repeated the baseline policy on the same
compiler, target and host class. All nine clients executed with their declared
output; cache, input and artifact audits passed. These observations were taken
before the concurrent full-suite qualification.

| Client | Baseline median seconds | Current median seconds (range) | Baseline median RSS MiB | Current median RSS MiB (range) |
|---|---|---|---|---|
| `result_values` | 7.75 | 7.43 (7.38–7.47) | 268.4 | 274.4 (274.1–277.7) |
| `inferred_traversal` | 7.15 | 6.69 (6.15–6.80) | 266.1 | 268.4 (268.2–269.2) |
| `capture_arguments` | 5.26 | 5.08 (4.99–5.29) | 246.5 | 243.4 (243.3–245.4) |

Costs remain close to the baseline. The Result client uses 6.0 MiB more median
peak memory; three observations per client do not establish a speedup or a
performance regression. The other seven workflows remain unmeasured.
Reports are retained in `.cache/api-roadmap/pass17/`; the
[qualification catalog](../guides/compatibility.md#qualification-checkpoint)
names the source commit and report digests. Completed workflow and measurement
reports survived an environment interruption and passed fresh artifact/log
audits. The unfinished full suites restarted in new output directories against
the same frozen inputs. Incomplete attempts do not count toward qualification.
The full standalone documentation matrix, copied-source delivery, macOS and
device execution were not rerun. All 117 examples ran inside both complete O3
suites. Earlier checkpoints remain in the catalog's qualification history.

## Keeping one result from two effects

Cats' [Apply implementation](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/Apply.scala)
defines left selection through applicative combination:

```scala
def productL[A, B](fa: F[A])(fb: F[B]): F[A] =
  map2(fa, fb)((a, _) => a)
```

Its examples accumulate both invalid inputs for `productL` and `productR`.
FP Mojo's `product_l` and `product_r` now delegate to the existing `map2`
owner with one stateless selection callback. Public left/right contracts
specialize the existing combination metadata. The context generator shares
one descriptor loop across pairing and both selections.

The State tutorial now uses `.product_r(get[State]())` to retain the updated
state without a callback or factory. Both recipe values are constructed before
the call; State transitions still execute in order at `.run(initial)`.
`followed_by(factory)` retains its separate conditional-construction contract.
Validation accumulates both failures, Result keeps its first failure, and List
retains one selected value for each Cartesian pair. The selected payload keeps
its exact origin and moves where the family permits it. Deferred execution,
IO outcomes and cleanup remain with their existing owners.

## Outcome-aware IO cleanup

Cats Effect's [MonadCancel syntax](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/syntax/MonadCancelSyntax.scala)
exposes `guaranteeCase` by forwarding to its effect owner. Pipeline now exposes
`guarantee_case` with the same composition pattern through the existing scoped
factory and finalization owners. The IO finalization example passes
`report_exit` directly and finishes with `run_io`, removing nested free calls
and explicit `scoped_io` adapters.

The body owns the resulting family, error channel and exit-case type. Shared
admission requires cleanup to match those types. `GuaranteeCaseContract` lets
generic wrappers forward that proof and name the resulting recipe and outcome.
This avoids asking the compiler to transfer equalities through independently
constructed exit-case and family types. The constant cleanup adapter also
receives the body's exit-case type; execution stays in the existing finalizer.

Native and library borrowing callbacks use the current signature descriptors.
`ScopedIO` retains actions that borrow the fresh exit case during cleanup;
ordinary callback results have an input-independent recipe type. External
origins remain exact. Construction and execution of cleanup are masked and
captured, unopened recipes do neither, and cleanup failures follow body failures.
The library's exit case exposes success, error and cancellation state; this
does not claim Cats Effect's complete Outcome or asynchronous runtime model.

## Appending Writer output without a recipe factory

Cats' [Writer example](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/docs/datatypes/writer.md)
appends output directly:

```scala
val tellExample = Writer("tell example", 1).tell("log append")
tellExample.run
```

The Mojo Writer tutorial now uses `.map(add_fee).tell("fee +2")`. Its callback
returns an ordinary Int; it no longer constructs a Writer or spells its recipe
type. The two-argument free `tell` supports explicitly selected inner logs,
and `TellContract` supplies generic admission, result, family and error metadata.

Appending delegates to the existing Censor capability. The shared binary
argument binder now supports either operand; the appended log is bound on the
right of the existing monoid combination. There is one implementation of bound
value movement, repeated copies and invocation. A one-shot base moves its log;
a branching base copies only the appended log. Neither route copies payloads.
This also preserves nested-log selection, stored failures and deferred errors.

## Running resources without a body callback

Cats Effect's [Resource implementation](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/Resource.scala)
provides a terminal for programs expressed entirely in resource composition:

```scala
def use_(implicit F: MonadCancel[F, Throwable]): F[Unit] = use(_ => F.unit)
```

Native Resource and IOResource expose this as `use_void()`, following the
library's existing `traverse_void` naming. Native execution delegates to `use`
with the shared ignored-input and constant-value adapters. IO execution
delegates to `surround` with a unit recipe. Both preserve acquisition and
release order, move-only owners and exact error types. Native execution occurs
immediately; IO execution stays deferred, including cancellation and masking.

The IO resource example now opens and closes a session with `use_void()`.
It no longer needs an unrelated body value, a projection callback or a pure
IO type annotation just to run the resource's lifecycle.

## One scoped IO admission rule

Resource use and effectful projection now share their declared input/error
admission with outcome-aware finalization. Native resource factories delegate
to the existing `scoped_io` admission owner. No second callback invocation or
scope-lifetime mechanism is introduced.

An IO resource exposes `ScopedCompatible`, `Used`, `EvalMapped` and
`EvalTapped`. Generic helpers can forward the public proof and name results
through the constructor contract's resource type. Existing callers spelling
the equivalent input/error equalities still compile. The execution context
supplies the exact error type to the shared scoped runner; resource metadata
also derives it from the resource. This avoids requiring the compiler to
transport associated-type equality through an independently inferred IOContext,
and removes two casts from finalization.

The compatibility probes found that resource methods rejected stored thin
native pointers against the preceding packaged commit. The following pass
addresses that gap.

## Stored resource factories without adapters

Cats Effect expresses `evalMap(f)` and `evalTap(f)` in terms of a resource's
existing scope. Mojo's corresponding methods now accept a stored thin pointer
with the same direct call syntax as a named function: `scope.eval_map(pointer)`.
`use(pointer)` follows the same admission rule. Pointers are copied at admission;
execution remains deferred in the existing scoped runner.

The native signature generator emits all three admission surfaces from the
shared read/result ABI descriptors. Pure, `raises Never` and typed-raising
functions retain their exact signatures; the existing library-callable and
closure parameter positions remain unchanged. Mutable and consuming callbacks
are rejected because a resource factory borrows the acquired value.

The scoped adapter retains the already inferred ReaderAction type as an
explicit witness, with an exact equality check against the callback result.
This keeps generic IO error proofs intact instead of re-projecting the program
through a callback's associated result type. The default witness preserves
existing scoped adapters. No invocation, capture storage or lifecycle policy
is duplicated.

Coverage includes all four register/memory ABI combinations, generic forwarding,
move-only resource cleanup, abandonment, native build failures, and independent
external value/error origins. Rejection fixtures use ordinary call syntax and
check incompatible inputs, results, error families, conventions and escaping
borrows. Generic helpers declaring native pointer types still need the native
ABI bounds; concrete callers do not.

## Consistent borrowing factory admission

`asks[Reader[Config]](pointer)`, `inspect[State[S]](pointer)` and
`scoped_io(pointer)` now accept stored native borrowing pointers directly.
They copy the pointer into the existing callback owner and preserve deferred
execution, typed errors and independent external value/error origins. Existing
closure ownership and positional type arguments keep their meanings.

One native factory descriptor now covers borrowed inputs as well as the
existing owned inputs. A capability can fix the input type, or the pointer can
supply it. Borrowed input admission requires no ownership trait; register and
memory ABI evidence remains explicit at the compiler boundary. Native void is
kept separate from an explicit `NoneType` result. Resource admission uses this
same descriptor with byte-for-byte unchanged generated overloads.

The projection overloads delegate to `Project`; scoped factories retain their
inferred IO action witness in the existing `_ScopedFactory`. There is no new
execution or lifetime owner. Coverage exercises all four ABI combinations,
generic forwarding, move-only input cleanup, abandonment, typed failures and
independent borrow origins. Invalid conventions, types, families and escaping
borrows are checked using ordinary calls without explicit callback bindings.

## Borrowing projections in introductory clients

The Reader tutorial now uses `asks` to compute a quote from move-only pricing
configuration. The State tutorial uses `inspect` to format a ticket directly.
Both remove a copy-producing read followed by a map, while retaining the same
outputs and deferred timing. `ask` and `get` remain appropriate when the whole
input is the requested payload. The tutorial distinguishes projection callback
ownership from the borrowed native callbacks used by mapping and binding.

## State execution with a selected output

`run_value` and `run_state` follow Cats'
[runA and runS](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/data/IndexedStateT.scala): run the State
computation normally, then map a projection over its base carrier. The pipeline
terminals infer the selected family; free functions and public contracts serve
generic callers. The stateful-capability example now uses `run_state` directly
when it needs only the updated counter.

Both terminals share one contract and executor. The existing operand selector
also accepts a pair through the canonical pair-transfer helper, so selection
does not duplicate tuple ownership logic. State's `(value, state)` order stays
unchanged. Neither element requires copying. Optional absence, stored Result
failure and deferred base execution keep their existing meanings. Native
execution and map-construction errors retain their exact compatible type.

Coverage includes generic wrappers, independent borrow origins, native void,
third-party base-map failures, move-only cleanup, abandoned deferred results
and repeated List mapping. Invalid families, state types, output shapes,
incompatible native errors, reuse and escaping borrows use ordinary calls.

## Writer output selection through the same pair owner

Writer pipelines now finish with `.run_value()` or `.run_log()` when only one
output is needed. They follow Cats'
[value and written](https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/data/WriterT.scala)
by mapping over the unwrapped base carrier. The Writer tutorial's notice uses
`.run_log()` directly and retains its existing output.

Both Writer terminals share one admission descriptor and implementation. They
use the same operand selector and pair-transfer owner as State, retaining
native moves, exact map errors, deferred timing and independent value/log
origins. Writer's public generic contracts remain separate from State's initial
state and run-error requirements. The additional `run_value` overload preserves
the existing State calls; invalid calls retain ordinary compiler diagnostics.

## Next passes

1. Run the next source/package compatibility and compile-cost checkpoint after
   these terminal changes, including the new examples and ordinary diagnostics.

Each pass retains the commit/push boundary above and proceeds to the next
qualified dependency. Release, deprecation and CI work are outside these passes.
