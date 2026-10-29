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
