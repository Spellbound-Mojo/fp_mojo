# Examples

Each example is a complete program in `docs/examples/` that you can run and
change. Run it from the repository root:

```sh
pixi run mojo run -I src docs/examples/<name>.mojo
```

The programs check their results with `std.testing`. Documentation tests also
compile them through source and precompiled package imports at O0 and O3 with
`--Werror`, then compare their output with the output shown on the site.

## Start with pipelines

| Example | What it shows | Page |
|---|---|---|
| `pipeline_quickstart.mojo` | A first fluent pipeline on the Mojo 1.2 nightly checkout | [First program](../index.md#run-a-first-program) |
| `optional_default.mojo` | Finish an Optional with the same lazy-default syntax as Result | [Pipelines tutorial](../tutorial/pipelines.md#finish-an-optional-with-a-lazy-default) |
| `value_defaults.mojo` | Use constants directly and choose when default computation runs | [Pipelines tutorial](../tutorial/pipelines.md#choose-a-constant-or-lazy-default) |
| `combinators.mojo` | Shared iterator stages in eager and lazy chains, without wrapper lambdas or type aliases | [Pipelines tutorial](../tutorial/pipelines.md#use-combinators-for-collection-stages) |
| `chained_pipeline.mojo` | A ten-stage chain with `pipeline(...).raising[E]().then(...)`: plain functions, closures and partials | [fp.functions](../reference/functions.md#chain-ten-stages-with-pipeline) |
| `kleisli.mojo` | Reusable effectful functions with clean eager and lazy callback syntax | [fp.functions](../reference/functions.md#compose-effectful-functions) |
| `partial.mojo` | Binding leading arguments with `partial`; binding a keyword with a closure | [fp.functions](../reference/functions.md#bind-leading-arguments-with-partial) |
| `quickstart.mojo` | The released-package quickstart using `pipe` | [Package installation](../start/installation.md#install-the-package) |
| `callable_pipeline.mojo` | A fixed-stage pipeline of plain functions over a consumed list | [Function reference](../reference/functions.md#other-pipeline-entry-points) |
| `callable_pipeline_generic.mojo` | Forwarding the fixed-stage pipe API through a generic function | [Function reference](../reference/functions.md#other-pipeline-entry-points) |

## Iterate and fold

| Example | What it shows | Page |
|---|---|---|
| `effectful_reductions.mojo` | Effectful folds, short-circuiting predicates and selected factories | [fp.combinators](../reference/combinators.md#fold-and-choose-effects) |
| `iteration.mojo` | Lazy selection, ordered reduction and initial-first snapshots | [Iteration tutorial](../tutorial/iteration.md) |
| `iteration_chaining.mojo` | Consuming method chains, both list collectors and native `enumerate` | [Iteration tutorial](../tutorial/iteration.md#chain-operations-with-methods) |
| `generic_fold.mojo` | One `fold_left` over scalars, SIMD vectors and a user-defined document | [fp.iteration](../reference/iteration.md#fold-scalars-simd-vectors-and-documents-with-one-function) |
| `iteration_generic.mojo` | Returning `map` and `scan_left` adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-adapters-from-generic-functions) |
| `iteration_filtering_generic.mojo` | Returning filtering adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-filtering-adapters) |
| `terminal_generic.mojo` | Generic terminal wrappers that keep the callback's exact error | [Iteration tutorial](../tutorial/iteration.md#generic-terminal-calls) |
| `control_flow.mojo` | `while_loop`, `fori_loop` and carry/output `scan` | [fp.control](../reference/control-flow.md#write-loops-and-a-scan-as-expressions) |

## Handle results and errors

| Example | What it shows | Page |
|---|---|---|
| `capture_arguments.mojo` | Bind several owned arguments without a wrapper closure | [Results tutorial](../tutorial/results.md#bind-arguments-before-the-callback) |
| `optional_result.mojo` | Convert absent optional input to a lazily constructed stored error | [Results tutorial](../tutorial/results.md#turn-optional-input-into-a-result) |
| `result_constructors.mojo` | Infer one side of Result construction with `ok[E]` and `err[T]` | [Results tutorial](../tutorial/results.md#construct-a-result-with-one-type-argument) |
| `results.mojo` | Stored domain errors versus raised callback failures | [Results tutorial](../tutorial/results.md#transform-only-the-active-branch) |
| `result_transform_generic.mojo` | Generic Result transformations | [Results tutorial](../tutorial/results.md#generic-transformations) |
| `attempt_adapters.mojo` | Select a native callback argument convention with a borrowed adapter | [fp.data](../reference/data.md#select-a-native-argument-convention) |
| `attempt_generic.mojo` | A generic transaction helper built on `attempt_kwargs` | [Results tutorial](../tutorial/results.md#generic-transaction-helpers) |
| `attempt_once.mojo` | Capturing the failure of a consuming thunk | [fp.data](../reference/data.md#attempt_once) |
| `result_once.mojo` | Consuming handlers in Result transformations and folds | [fp.data](../reference/data.md#Result.fold_once) |

## Store values in place

| Example | What it shows | Page |
|---|---|---|
| `foundations.mojo` | Callbacks, folds, typed errors and a `Choice` matched together | [Values stored in place](../tutorial/choices.md#store-a-value-in-a-choice) |
| `optional.mojo` | Matching a standard `Optional` and a `Result`, with a guard | [Values stored in place](../tutorial/choices.md#match-result-optional-and-controlflow) |

## Declare and match data

| Example | What it shows | Page |
|---|---|---|
| `shapes.mojo` | A sum type matched with clauses, a guard, a context and a pair of values | [Matching tutorial](../tutorial/matching.md) |
| `traffic_light.mojo` | Matching two values, and three with a plain one, by every combination of constructors | [Matching tutorial](../tutorial/matching.md#several-values-at-once) |
| `expression.mojo` | Structural recursion over an inductive expression type: evaluation, rendering and rewriting, with `Next` and shared values | [Inductive types tutorial](../tutorial/recursion.md#evaluate-render-and-simplify-an-expression) |
| `file_tree.mojo` | Recursive fields in a `List` and an `Optional` | [Recursion tutorial](../tutorial/recursion.md#lists-and-optional-children) |

## Use algebra and effects

| Example | What it shows | Page |
|---|---|---|
| `algebra_core.mojo` | `pure`, `map`, `flat_map` and `traverse` over four native carriers | [fp.algebra](../reference/algebra.md#use-one-set-of-operations-over-four-carriers) |
| `algebra_choices.mojo` | Mapping, monadic bind, `map2`, `ap` and List's Cartesian combination | [Algebra tutorial](../tutorial/algebra.md#choose-the-operation-by-what-the-next-step-needs) |
| `algebra_traversal.mojo` | `traverse` and `sequence`, early termination and empty input | [Algebra tutorial](../tutorial/algebra.md#collect-results-with-traverse-and-sequence) |
| `parallel_validation.mojo` | Collect independent errors through Result, Piped and iterator composition | [Combinators reference](../reference/combinators.md#accumulate-independent-validation-errors) |
| `fluent_effects.mojo` | Fluent combination, effectful observation and traversal without output collection | [Combinators reference](../reference/combinators.md#combine-and-inspect-effects) |
| `monad_sequencing.mojo` | Retain originals or take the next effect's values in eager and lazy chains | [Combinators reference](../reference/combinators.md#sequence-dependent-effects) |
| `traversal_composition.mojo` | Flattening, filtering and sequencing effectful results | [Combinators reference](../reference/combinators.md#flatten-and-filter-effects) |
| `transformer_recovery.mojo` | Compare state restored at the recovery boundary with state retained below ResultT | [Combinators reference](../reference/combinators.md#recover-a-selected-error-layer) |
| `error_recovery.mojo` | Recover native Results and selected inner errors in ResultT | [Combinators reference](../reference/combinators.md#recover-a-selected-error-layer) |
| `selective_recovery.mojo` | Observe failures and recover only matching stored errors | [Results and recovery](../tutorial/results.md#recover-selected-errors) |
| `result_outcomes.mojo` | Map, observe and continue either Result branch | [Results and recovery](../tutorial/results.md#compose-either-outcome) |
| `shared_outcomes.mojo` | Validate, observe and handle outcomes through an explicit effect family | [Combinators reference](../reference/combinators.md#validate-and-observe-outcomes) |
| `effects_reader.mojo` | Pricing configuration with `ask`, `local` and a borrowed deferred callback | [Effects tutorial](../tutorial/effects.md#read-configuration-with-reader) |
| `effects_state.mojo` | Reading, updating and resetting a counter with State | [Effects tutorial](../tutorial/effects.md#pass-an-evolving-counter-through-state) |
| `effects_writer.mojo` | Ordered logs with Writer, `tell`, `listen` and `censor` | [Effects tutorial](../tutorial/effects.md#accumulate-output-with-writer) |
| `state_result.mojo` | How transformer order decides whether a failure keeps its state | [fp.effects](../reference/effects.md#choose-whether-a-failure-keeps-its-state) |

## Build an application

| Example | What it shows | Page |
|---|---|---|
| `config_parser.mojo` | Parsing configuration lazily, collecting Results and validating with a fold that stops early | [Application tutorial](../tutorial/application.md#parse-and-validate-configuration) |
| `job_router.mojo` | Routing a queue of commands with guarded, raising clauses, a context and `attempt` | [Application tutorial](../tutorial/application.md#route-commands-with-guarded-clauses) |

The [non-empty validation example](../reference/data.md#non-empty-collections-and-validation)
uses NonEmptyList for both accumulated errors and successful traversal shapes.

## Success with warnings

[Inclusive-or validation](../reference/data.md#success-with-warnings) keeps a value
with warnings and compares sequential and independent diagnostic accumulation.

## Prefixes and indexed iteration

The [iterator expansion example](../reference/iteration.md#prefixes-indexed-mapping-and-consuming-terminals)
combines lazy prefixes, native zip, indexed mapping and explicit terminals.

The [selected workflow](../reference/functions.md#select-family-and-native-errors-before-callbacks) combines traversal, folds and n-ary operations with one native error selection.
