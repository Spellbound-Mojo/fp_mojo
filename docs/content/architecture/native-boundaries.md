# Native Mojo boundaries

The `nightly` library is pinned to Mojo 1.2.0 (2016d0cd). The tables below
record the Mojo 1.1 behaviors that originally shaped the design. They remain
historical evidence for retained boundaries, not a claim that every defect
persists in 1.2. New native features do not broaden the library's supported
API without a separate review.

## Mojo 1.2 compatibility

- `std.hash` replaces `std.hashlib`. Native `Dict` hasher parameters require
  `Defaultable & Hasher & Deinitable`; dictionary adapters carry those same bounds.
- Native function traits no longer expose named signature aliases such as
  `F.A`, `F.R` or `F.E`. Callback adapters check the exact structural function
  trait and invoke it directly, retaining the public type and origin admission
  predicates. Forwarding does not inject synthetic function parameters.
- Tuple and variadic-pack `consume_elements` handlers are runtime closures.
  Their explicit reference captures retain the destination slots while each
  source element moves once; this adds no copying requirement.
- Consuming receivers that partially move fields across `try` boundaries are
  rejected. Error adaptation uses the existing receiver helpers, or an owned
  static boundary, so the handler never reuses a partially consumed receiver.
- Inferring a nested native `Result.map_err` or `or_else` call from a generic
  `Piped` overload crashes this compiler. Those forwards use the shared native
  callback view and Result's existing library-callback entry point.
- Direct generic callback fields can lose their native function witnesses.
  `NativeUnary` and the private lazy adapters use the existing inline optional
  cell, without allocating or copying captures. `NativeUnary.function` becomes
  `function()` for borrowing and `into_function()` for consuming extraction.
- A consumed scalar forwarded through the generic borrowing bridge can arrive
  as zero at O0. Mandatory inlining of `invoke_borrowed` preserves the payload
  reference and fixes the effectful reduction example through both import routes.
- An unconstrained variadic pipeline overload outranks the fixed thin-function
  overloads. Inferred library-stage packs now carry their existing callable
  requirements in the signature, allowing plain functions to reach the fixed
  overloads. Explicit-result and explicit-error forwarding remain available.
- Native callback signatures referring directly to `Self` aliases can fail
  plain-function conversion. `Piped.then`, Result folds and transformations infer callback input
  types independently and require equality with the stored payload in `where`
  clauses. These Result operations use the shared native invocation bridges.
- Explicit `raises Never` callbacks require a literal `Never` signature during
  native dispatch. An implicit no-value return is `type_of(None)`, distinct from
  `NoneType`; discarded Result observers dispatch through its literal signature
  inside the shared borrowing bridge, preserving the existing overload set.
- Native `map_n` and `par_map_n` overloads use fixed tuple signatures for one
  through eight operands. Mojo 1.2 can crash before checking a variadic pack's
  length, including when both forms are available. These boundaries delegate
  to the existing product runner. Ordinary calls stay the same; explicit extra
  carrier type packs become inferred or individually named carrier types.
  Library callable overloads retain their variadic packs. Inferred `map2` overloads
  infer the second carrier independently, then constrain its exact payload.
- Generic `Piped.then` now infers a native callback's exact error without an
  explicit hint. The former rejection fixture is replaced by a positive
  propagation test and a rejection test for an incompatible enclosing error.
- Native Result `flat_tap_err` and `attempt_tap` infer the complete callback
  result before checking its stored error and embedded origins in `where`.
  The existing positional `C`/`X` bindings and named `U` binding remain available.
- Native Result outcome handlers infer their result types independently, then
  require equality in `where`. `redeem_with` and Piped's native `or_else` infer
  the complete returned Result before checking its payloads. This avoids
  conflicts with explicit family bindings while preserving positional callback
  and error bindings, and named `U`/`V` bindings.
- Native family `map` and `flat_map` entries are always inlined. Otherwise,
  captured callbacks forwarded through generic functions can receive invalid
  capture storage at O0 when the entry builds a borrowed reference adapter.
  Invocation and family execution still use the existing shared drivers.
- Native callbacks that mutate owned captures must be marked `@always_inline`
  on Mojo 1.2, including stored borrowing predicates. Without it, a native-only
  reproducer records `[1, 1, 1]` instead of `[1, 2, 3]` at O3. An explicit mutable
  library callable is an alternative. Annotated iterator callbacks retain the
  state-update and destruction checks at O0 and O3.

The MAX pin is 26.7.0 for the optional device environment. The released
community package remains FP Mojo 1.0.0 and requires Mojo 1.1.0; installing
that release with 1.2 is not supported. Use the nightly source checkout.

## Mojo 1.2 qualification

The environment and lockfile select stable Mojo 1.2.0, but the library's full
compatibility migration is **incomplete**. These are Linux x86-64 checkpoints
from 2026-10-24; neither macOS nor GPU execution was requalified.

| Check | Result |
|---|---|
| Locked default environment | Compiler reports `Mojo 1.2.0 (2016d0cd)` |
| Whole-package precompilation | Passes with `--Werror` |
| Standalone test modules, source at O0/O3 | 232/257 at each level; the same 23 compiler crashes and 2 compilation errors remain at each level; all compiled tests run successfully |
| Compile-failure fixtures at O3 | 560/673 at the broad checkpoint; 24 additional fixtures subsequently match their declared rejection in the focused run below |
| Runnable examples, source/package at O0/O3 | 188/220 at the broad checkpoint; the four regressed generic-pipeline runs subsequently pass |
| Python tooling tests | 36/36 pass, including GNU time resource accounting |
| Strict documentation build and generated-overload check | Pass |

The current source report is `.cache/mojo12-source-o0-o3-4/report.json`:
464/514 test runs pass, with 12 more passing modules at O3 and no regressions
against `.cache/mojo12-fix-individual-o3-3/report.json`. The broad rejection and
example checkpoints are `.cache/mojo12-fix-rejects-6/report.json` and
`.cache/mojo12-fix-docs-5/report.json`. Inputs were unchanged during each run.
The rejection checkpoint contains 107 compiler crashes, 5 diagnostic mismatches
and 1 unexpected acceptance before the focused fixes below. Compiler crashes
are failures, never successful rejection checks.

The broad runs exposed a regression in explicit `raises Never` thin function
pointers stored by `as_unary`. Literal `Never` dispatch fixes the four affected
test modules at O0/O3 and the generic-pipeline example through both import
routes. The focused reports are `.cache/mojo12-thin-never-matrix/report.json`
(26/28 pass; the remaining two runs reach the existing `attempt` blocker) and
`.cache/mojo12-thin-never-docs/report.json` (4/4 pass).

The native entry fix passes 48 source/package checks at O0/O3 in
`.cache/mojo12-native-entry-matrix/report.json`. The Result and fluent outcome
fixes pass 152 source/package checks at O0/O3 in
`.cache/mojo12-positional-outcome-matrix/report.json`, including explicit
positional error and callback bindings. Its focused rejection companion,
`.cache/mojo12-positional-outcome-rejects/report.json`, passes 69/80: 24 more
declared rejections than the broad checkpoint, with no previously passing
fixture regressing. Six compiler crashes and five incidental error-context
diagnostics remain failures. Each report records unchanged inputs during its
run. The affected examples also pass all 12 source/package checks at O0/O3 in
`.cache/mojo12-positional-outcome-docs/report.json` and
`.cache/mojo12-native-entry-docs/report.json`. These focused checks do not
replace complete package, rejection and example reruns.

The earlier 2026-10-23 baseline had 487/673 declared rejections and 118/220
example runs passing. All four grouped package executables failed compilation;
standalone modules are being used to isolate failures. The O0 scalar-forwarding
runtime failure in `effectful_reductions.mojo` has since been corrected.

Outstanding work includes `attempt` overload inference, remaining fluent error
and outcome overload conflicts, `scan_map` result inference, stored callbacks
with implicit void returns, generic native witnesses, and rejection fixtures.
Result-specific `Piped` combinators retain their existing positional type
bindings. Compatibility fixes must preserve those bindings.

The old `Piped.then` rejection has been replaced with positive exact-error
propagation coverage and a rejection for an incompatible enclosing error type.
The broad checkpoint unexpectedly accepted `terminal_fold_until_result.mojo`
despite distinct embedded origins for the requested break payload and callback
result. The subsequent [origin and pipeline fixes](#origin-checks-and-one-stage-pipelines)
address this contract regression. Ownership, origins and error guarantees must
not be relaxed to obtain a passing baseline.

The grouped package suite, compile-time budget and device checks have not been
requalified. Existing performance numbers remain Mojo 1.1 measurements.

### `attempt` inference on Mojo 1.2

Keyword-pack callbacks now use `attempt_kwargs(function, ...)`, including when
the pack is empty. Ordinary positional calls retain `attempt(function, ...)`.
Both entry points retain the existing result/error inference and native
argument conventions; the name separates their overload candidates. In the
source checkpoint above, 19 of the 25 remaining modules first fail at `attempt`;
resolving those first failures may expose other blockers.

Library-independent overload probes isolate an inference failure. A pair of
overloads accepting `F: def() raises E -> T` and
`F: def(var **kwargs: K) raises E -> T` crashes when resolving a plain raising
function, even though one overload matches. Fixing both the result and keyword
value types still crashes while `E` is inferred. Borrowed capturing callbacks
also reproduce the crash.

The controls in `.cache/mojo12-attempt-v1/controls-report.json` were compiled
at O0 and O3 on Mojo 1.2.0 (2016d0cd):

| Probe | Outcome at both levels |
|---|---|
| Non-raising callbacks and signatures | Expected overloads selected |
| Literal `raises Error` or `raises Int` signatures | Expected overloads selected |
| Generic `raises E`, with `[E=Error]` supplied at each call | Expected overloads selected |
| Keyword overload alone, with matching keyword callbacks | Expected overload selected, including an empty pack |
| Generic `raises E` inferred across positional and keyword signatures | Compiler crash |
| Infer an unconstrained callback first, with a separate defaulted signature parameter | Compilation error: result and keyword value types cannot be inferred |

These probes check inference and overload selection, not complete forwarding
semantics. Fixing the error type or adding caller hints does not satisfy the
existing inferred API. Signature aliases and parameter reordering also failed
to avoid the crash in exploratory probes, motivating the separate keyword
entry point.

The split alone does not complete forwarding compatibility. The first source
run at O3, `.cache/mojo12-attempt-kwargs/initial-source/report.json`, passes
4/21 affected modules: `test_errors` and `test_cq_closure_operations` newly pass,
and the previously passing keyword-value ownership and `attempt_once` tests
remain passing. At that checkpoint, read callbacks still matched mutable
overloads ambiguously; consuming and mutable argument inference still crashed. The keyword
integration module now reaches an implicit-void callback witness failure.
No argument conventions or error types have been weakened to bypass these
remaining failures.

The final focused report,
`.cache/mojo12-attempt-kwargs/qualification/report.json`, checks source and
precompiled imports at O0/O3 with unchanged inputs. Package precompilation
passes with `--Werror`. Five of 22 selected test modules pass in all four
combinations (20/88 runs), including the new entry-point regression covering
empty packs, exact inferred errors, generic forwarding and borrowed captures.
The other 17 modules fail compilation at both levels and through both routes;
no compiled positive program fails at runtime. The source comparison confirms
the two newly passing modules above and no regression among the selected
previously passing modules.

The five affected documentation examples pass 8/20 runs: `foundations` and
`attempt_once` pass through both routes at both levels; `attempt_generic`,
`results` and `job_router` remain compilation failures. At O3, the selected
rejection fixtures pass 44/94 source/package checks; 48 runs crash the compiler
and two report an incidental error-context diagnostic. No rejection fixture
is unexpectedly accepted. These focused results do not replace a full-suite
qualification.

### Ranking read and mutable `attempt` overloads

`attempt` and `attempt_kwargs` now add one defaulted compile-time parameter
per mutable argument to their mutable overloads. Mojo 1.2 admits a read
callback where a mutable callback is expected without charging a conversion
penalty. Its final overload tie-breaker prefers fewer parameter bindings, so
these defaults let an otherwise equally suitable read overload win. They
follow `F`, preserving existing positional callback type bindings, and do not
add runtime arguments or change how a callback executes. Callers leave them
at their defaults. This uses the pinned compiler's
[overload ranking implementation](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/lib/MojoParser/OverloadFitness.cpp#L218).

The initial source comparison at O3 passes 6/22 affected modules, up from
5/22 after the keyword split. `test_attempt_forwarding_borrowed` now passes;
the larger forwarding tests proceed past their read ambiguity to existing
consuming or mutable inference crashes. The new `test_attempt_borrow_ranking`
regression checks a move-only input borrowed repeatedly, generic read
forwarding, positional callback type bindings, exact errors, captured
callbacks, and two shared arguments referring to the same owner, including
keyword-pack calls.

The final focused run, `.cache/mojo12-attempt-ranked/qualification/report.json`,
precompiles the package with `--Werror` and checks source/package clients at
O0/O3. Seven of 23 selected test modules pass in all four combinations (28/92
runs), including the new regression; 16 modules still fail compilation. The
`job_router` example also now passes in all four combinations, bringing the
five selected examples to 12/20 runs. No previously passing selected case
regresses. Rejection fixtures pass 88/188 checks across both levels and routes;
none is unexpectedly accepted. Inputs remained unchanged during verification,
and every passing case has a clean audit. This remains focused verification,
not a replacement for the broad qualification above.

Effect unification was tested alongside ranking and was not adopted. Although
the compiler infers `E = Never` for non-raising callbacks, some resulting calls
lose their native closure witness when instantiated. Replacing each
pure/raising pair with a single `raises E` overload reduced the same source
selection to 3/22 passing modules. Isolated probes also still crash while
matching an incompatible convention, including with `E: AnyType`; this happens
before overload ranking. Separate pure and raising signatures remain necessary
for the currently working API. Prototype comparisons and logs are under
`.cache/mojo12-attempt-ranked/`; full `attempt` compatibility remains incomplete.

### Keyword no-value returns

Zero-prefix `attempt_kwargs` calls now invoke native callbacks through
`callables.native._call_native_keywords`. As with the existing borrowed native
dispatcher, the helper receives `F` without a native signature bound and
recovers the literal no-value or explicit `Never` signature before invoking
it. Recovering that signature inside the original `F: def(...) -> T` overload
retains the wrong generic result witness. Result wrapping and error capture
remain in `attempt_kwargs`, and the public signatures are unchanged.

`test_attempt_keywords_void` covers generic forwarding, empty packs, overlapping
keyword names, exact typed errors, `StopIteration`, explicit `Never`, the
distinction between native no-value returns and `NoneType`, and cleanup of
owned keyword values on success and failure. Ordinary zero-argument and
consuming wrappers in `test_attempt_generic` also use `attempt` again; those
four calls had been incorrectly renamed during the keyword split.

The native-library report at
`.cache/mojo12-attempt-adapters/native-qualification/report.json` precompiles
with `--Werror` and checks source/package imports at O0/O3. Nine of 24 selected
test modules pass in every combination (36/96 runs). The existing keyword
integration test is restored, and the new void regression passes; 15 modules
still crash during compilation. Previously passing selected cases remain
passing. Examples remain at 12/20 runs and rejections at 88/188 checks, with no
unexpected acceptance. A subsequent four-case run at
`.cache/mojo12-attempt-adapters/void-final/report.json` also verifies owned
keyword cleanup when the no-value callback raises.

### Convention adapters

`fp.data` now exports `mutating`, `consuming`, `mut_owned` and
`mut_owned_kwargs`, also available from the compatibility module
`fp.data.result`. They admit one signature family before `attempt` sees the
callback: one mutable argument, one owned argument, a mutable/owned pair, or
that pair followed by a native homogeneous keyword pack. Existing native
overloads remain available. The [reference](../reference/data.md#select-a-native-argument-convention)
shows the four call forms.

The private native views deliberately have no `__call__` method, so they do
not participate in competing native closure-trait matches. They borrow the
callback, retain its exact type and origin, and use the existing native unary
view for consuming calls. Copying a view copies only its borrowed handle.
The Result bridge holds owned arguments in temporary `Optional` cells and
moves each once; `_attempt_core` owns success/error capture. Native invocation
lives in `callables.native`, including the literal no-value and explicit
`Never` signatures required by Mojo 1.2. The no-value correction to the shared
owned unary dispatcher also serves `NativeUnary` and pipeline stages.

Separate pure and raising factories preserve native signature evidence.
Valid calls infer their argument, result and error types, including through
generic forwarders. A saved adapter may be reused while its callback remains
alive and unmoved. No ownership or origin checks are bypassed. Owned captures
that mutate still need the existing `@always_inline` workaround.

The prototype was qualified before promotion through source/package at O0/O3
in `.cache/mojo12-attempt-adapters/qualification-v2/report.json`: all 20
adapter-client runs, 36 supported-native controls and four `job_router` runs
passed. Rejection clients passed 32/36 checks; all four failures were compiler
crashes when applying `mutating` to a consuming callback. This reproducer is
now `tests/compile_fail/attempt_adapter_wrong_convention.mojo`. Its expected
diagnostic remains a normal type rejection; a compiler crash is a failure.

Permanent regressions cover reusable captured callbacks, exact errors,
mutation before failure, nested Results, `StopIteration`, no-value returns,
move-only cleanup and external origins. Rejection fixtures cover aliasing,
use-after-move, moving a callback while its view is live, read-only inputs,
and incompatible error origins. The two generic ownership clients and the
pipeline error client use the public adapters, as do the Result examples.

The promoted-library report at
`.cache/mojo12-attempt-adapters/promoted-qualification/report.json` precompiles
the whole package with `--Werror` and records these source/package O0/O3 results:

| Scope | Result |
|---|---|
| Six adapter modules, including generic ownership and origins | 24/24 runs pass |
| Thirteen existing native, callable and ownership controls | 52/52 runs pass |
| Adapter, generic transaction, Result and job-router examples | 16/16 runs pass, including their documented output |
| Nine rejection fixtures | 32/36 checks pass; the incompatible adapter fixture crashes in all four combinations |
| Migrated pipeline error client | 0/4 runs pass; it now reaches a separate native witness failure in the one-stage `pipe(2, same)` call, where `same` declares `raises Never` |

Inputs stayed unchanged during the run, and every passing case has a clean
audit. The normal grouped source suite at O3 also passes all five modules
selected by `--filter attempt_adapter`, with no audit failures. Documentation
checks and all 36 tooling tests pass. This is focused qualification, not a new
full-library baseline.

Additional probes confirm that storing a plain no-value callback with
`as_unary(f).call(...)` still loses native signature evidence, for both pure
and explicit `Never` callbacks. The isolated probes fail with both the original
owned unary dispatcher and the promoted dispatcher; the borrowed `consuming`
adapter passes. Reproducers and comparison logs are under
`.cache/mojo12-attempt-adapters/stored-void-*`. The no-value adapter fix does
not establish support for every stored native callback.

Full compatibility remains incomplete: these four adapters do not cover all
two-argument conventions or all keyword prefixes. Selecting an incompatible
adapter can still crash the compiler inside the factory. Runtime performance
has not been requalified. The adapter mechanism is a library workaround for
the pinned compiler, not a change to its overload rules.

### Origin checks and one-stage pipelines

The `fold_until` origin discrepancy was a real admission defect. A stronger
compile-only reproducer returned a read-only `Span` of a local List through a
callback declaring a different break origin. The uncorrected library accepted
it; the reproducer was never executed. A direct return of that local Span was
rejected by native origin checking. Type equality evaluated in an ordinary
body did not distinguish the two borrowed Span types, so a body assertion
would not establish the required guarantee.

Both free and fluent native `fold_until` now infer the callback's actual break
type as `Q`, separately from the requested `B`, and require `Q == B` in their
public signature. `B` defaults to `Q`, keeping inferred calls, named `B=` and
existing positional callback type bindings. The driver runs with the exact
callback type, and only the final result is rebound under the checked equality.
Pure and raising local-escape fixtures exercise both entry points; valid tests
check pointer identity, empty input, errors and generic forwarding. The original
rejection fixture now constructs `Break` from the other origin instead of only
returning `Continue`.

One-stage `pipe` now sends explicit `raises Never` callbacks through
`callables.native._call_native_never`. The existing owned unary dispatcher uses
the same helper, which retains literal thin, closure and no-value signatures.
Its input/result bounds remain `Movable`, preserving the existing `pipe`
contract. Other error channels retain their existing dispatch. Regression
coverage includes generic forwarding, reusable move-only captures, owned
arguments, destruction counts and native no-value returns.

The next migration pass also updates 45 calls in nine existing test modules to
the four approved `attempt` adapters. Those modules still contain other
conventions, including one-prefix keyword callbacks and additional binary
combinations, so migration of these calls alone does not qualify whole modules.
An exploratory invalid `Continue`-payload origin case also still crashes during
inference; it is not counted as a successful rejection. The stored no-value
`as_unary` limitation and the generic terminal predicate conversion failure
remain separate from the one-stage pipeline fix.

The focused report `.cache/mojo12-followups/qualification-v2/report.json`
precompiles the whole package with `--Werror`. All 24 selected positive modules
pass through source/package at O0/O3 (96/96 runs), including the previously
blocked pipeline integration test. Three examples pass with their documented
output in all four combinations (12/12). Rejection checks pass 44/48: the
original break-origin fixture and all four local-escape fixtures pass; the four
failures are the pre-existing compiler crash in
`terminal_fold_until_input.mojo`. No selected rejection is unexpectedly accepted.
All nine partially migrated modules still fail at unsupported calls at source
O0/O3 (0/18); their first blockers include owned/read or read/owned pairs,
mutable/read pairs, and one-prefix keyword callbacks. No tests or call shapes
were removed to obtain these results. Inputs stayed unchanged during the run,
and every passing case has a clean audit. Documentation, API metadata and all
36 tooling tests pass. This remains focused verification rather than a new
full-library baseline.

## Callables and argument packs

| Mojo 1.1 behavior | Library consequence | Replacement trigger |
|---|---|---|
| Function types are traits: a capturing closure satisfies `F: def(var T) -> U`. A non-generic struct with `__call__` can conform to such a trait; a generic struct cannot conform to an inferable function-type trait. | Library callables conform to library protocols (`Unary`, `Binary`, `Thunk`), and native callbacks keep their own overloads. | Generic structs conforming to inferable function traits. |
| A function's signature is known only at a parameter of that exact function type; through a plain generic `F`, `conforms_to(F, def(Int) -> String)` is false even for an exact match. A non-raising closure does not match `def(A) raises E -> R` with `E` inferred. | Entry points that accept closures have one overload per arity, with separate non-raising and raising overloads. | Signature evidence for generic parameters, or `raises Never` inference for closures. |
| A plain function converts both to a read-pack signature and to a closure-typed parameter; with explicit parameters at the call, a two-parameter plain function is ambiguous between the two. Fixed-arity `thin` signatures are preferred over closure overloads without ambiguity. | Pipelines and match clauses take plain functions through fixed-arity `thin` signatures, one overload per count, instead of one pack overload. | Unambiguous ranking of pack and closure overloads. |
| A closure cannot be returned from the scope that declares it, and `Some[def(Int) -> Int]` is not a concrete return type. An existing callable can be returned unchanged through its concrete type. | `flow`, `compose`, `flip` and `partial` return concrete library structs. | Scope-safe closure return with the full residual signature. |
| A plain (`thin`) function converts to `def(var a: A, *args: *Rs) raises E thin -> R`, inferring every type, with `E = Never` when it does not raise. A capturing closure does not convert. | `partial` targets plain functions. | Closure conversion to pack-typed signatures. |
| No concatenation of unpacked positional arguments, no `Tuple` unpacking into a call, one variadic pack per signature, no public `VariadicPack` constructor. The private `_create_dynamic_pack` erases origins and crashed the compiler when used generically. | One `partial` overload per bound count (up to 8); no nested partials. | Pack concatenation or a public, origin-preserving pack constructor. |
| Converting a read parameter into an **owned** pack delivers a dangling value for types that are not `ImplicitlyCopyable`. | `partial` forwards remaining arguments as a read pack; owned delivery to plain functions uses fixed signatures. | Correct owned-pack conversion. |
| A pack-typed function and a fixed-arity function have different calling conventions; `rebind` between them is rejected. Pack-to-pack rebinding that agrees at instantiation works. | `Partial.call` rebinds to the one- or two-element pack type. | — |
| Keyword packs are homogeneous, cannot be forwarded into named parameters, and parameter names are not reflected. | No keyword binding in `partial`. A call needing keywords or defaults is written as a closure. `attempt_kwargs` forwards only native `**kwargs: K` packs. | Heterogeneous keyword packs forwarded into named parameters, or signature reflection. |
| `mut` parameters do not convert to pack-typed signatures. | `partial` rejects `mut` parameters. | — |
| A factory's `where` clause gives no evidence in its return type: a reference to a generic function with a closure-typed parameter fails there ("lacking evidence"), while a struct with that parameter works. Such a struct constructed inline as another constructor's argument is rejected ("cannot implicitly convert X to X"); built into a local first, it is accepted. | Delivery adapters are structs, and factories build them in a local first. | Where-clause evidence in signatures. |
| A conditional conformance whose `where` clause inspects a function type directly (`conforms_to(F, def(A) -> R)`) makes the struct's methods `capturing`, which breaks the conformance. | `Composition` takes its arity as an explicit parameter computed by `flow` and `compose`. | — |
| A fully concrete variadic callable constraint (`var *values: Int` returning `Int`) works; making its input or result generic loses conformance. | No generic positional-pack callable bridge. | Generic variadic callable conformance. |
| A variadic pack keeps a plain function's exact type (`Fs[i] == def(var Int) thin -> Int` holds) but no signature evidence, and a type cannot be pattern-matched to extract its result. Function reflection (`reflect_fn`) offers only names; its `parameter_types`, `return_type` and `is_raising` are listed as future work. | `pipe`, `flow` and `compose` accept plain functions through one overload per stage count (two to eight), each stage spelled as its own thin signature; longer or mixed chains promote with `as_unary`. `match` and `rewrite` have one generated overload per clause count, one to sixteen. `piped(value).then(f)` chains any number of stages, one inferred call each. | Signature evidence for pack elements, function reflection of parameter and return types, or type pattern matching. |
| A plain function whose parameter, result or error types are still symbolic converts only to a spelled thin signature, never to a closure trait such as `def(var A) -> R`; a thin function type has no witness for that trait at instantiation either. | The fixed-arity pipeline overloads store plain functions as `_ThinFunction` values, not `NativeUnary`. | Thin-to-closure conversion under symbolic types. |
| A member alias of a struct that stores a native function (`NativeUnary[...].Error`) is not reduced in a `raises` clause, so a caller whose context raises `Error` cannot propagate it. | Native algebra overloads name the instance's error through `_ErrorProbe`, a struct carrying only the callback's types, and check in the body that the stored callback gives the same error. | Reduction of such aliases in signatures. |
| The generic `Iterable` protocol only borrows a collection; consuming iteration is `IterableOwned`. | Iteration sources accept native iterators and `IterableOwned` collections, which are consumed; borrowed iteration stays the native `iter(values)`. | — |

## Generic code

| Mojo 1.1 behavior | What to do |
|---|---|
| Callback metadata such as `F.E`, `F.T` or `F.U` is not reliably exposed through a precompiled package. | In generic wrappers pass `E=E` explicitly at every call, and never read those attributes. `flat_map` checks its inner type inside the factory. |
| `rebind` accepts some distinct structs with identical layout. | Keep a `comptime assert type_of(x) == R` next to every `rebind_var[R]`, as in the pipeline wrapper pattern. |
| Embedded origins are compared only in signature constraints; a late `comptime assert` on type equality can admit types from different owners. | Put type and origin admission in `where` clauses (the `*Compatible` predicates). |
| Trait methods cannot have `where` clauses. | Trait hooks document their preconditions; public functions carry the constraints. |
| A default method in a derived trait cannot satisfy an ancestor requirement for a parametric struct under `mojo precompile`, and a conformer must spell its signatures with the trait's associated names. | Receiver modes are separate traits; always run a package precompile after changing traits. |
| Member aliases of structs instantiated with symbolic parameters are not reduced. | Spell result types structurally where generic code needs them. |
| `TypeList` slicing leaves a deferred bound that hides concrete results. | Pipelines use known-length `tabulate` before reducing. |
| A thin scan callback specialized over a symbolic pointer origin can fail conversion to a closure trait with `closure conformance alias A cannot reference parameter`. Native-only binary forwarding reproduces it. | Forward through a spelled thin `(var A, var T) -> Tuple[A,Y]` wrapper, explicitly passing `A`, `T`, `Y`, or use a library `Binary`/`MutableBinary` callable. The scan tests cover both paths without erasing origins. |
| Iterator wrapper parameter names matter: renaming `T`/`U` to `T`/`S` around the lazy callback loses conformance, and one combined heterogeneous map/scan factory loses the scan callback's metadata. | Keep the parameter names shown in the tutorial's generic examples. |
| A function-type trait is identified by the names it spells: `def(var T) -> R` and `def(var A0) -> R` are different traits. Forwarding a callback from one to the other inside generic code loses the `__deinit__` witness of the handler that stores it. | `as_unary` spells `def(var A) -> R`, so a wrapper promoting a callback typed `def(var B) -> R` must forward plain functions through thin signatures instead (see the [pipeline tutorial](../tutorial/pipelines.md#forward-through-a-generic-function)). |
| A capturing closure received through a generic function-typed parameter and then stored in a struct fails to instantiate ("rebind input type does not match"); plain functions work. | Generic wrappers that store callbacks accept plain functions; closures are passed to the library directly. |
| `type_of(call(...))` in a return annotation crashed the compiler. | Use the public iterator aliases and explicit result types. |
| One `try` block can only contain calls raising one error type. | Adapt errors with the `_as` helpers in `callables._receiver`. |
| A field cannot be moved out of a temporary, or partly out of a local. | Provide a consuming accessor (`def take(deinit self) -> T`). |
| `match` and `case` are keywords. A function named `` `match` `` in backticks is declared, imported and called as `fp.match` or `` `match`(...) ``. | `fp.match` is a backticked function; module access needs no backticks. |
| Inferring a non-raising function's error under a `Movable & Deinitable` bound yields an uninhabited type that is not equal to `Never`; a `try` around a call that raises it crashes the compiler. Under an `AnyType` bound the error is `Never`. | Signatures that catch a callback's error infer it as `AnyType` and normalize it with `_internal.errors._NativeError`; `_forward` is the one `try` around such calls. |
| Nested calls to an overloaded function are resolved by backtracking: compile time grows exponentially with the nesting depth. | Nested construction uses one function name per overload (`_push1`, `_push2`, `_push3` in matching). |
| A member alias reached through a chain of generic structs (a type computed from a list of sixteen clause types) takes compile time exponential in the chain's length when it appears in a signature. | Generated signatures spell such types flat over their parameters (`_Result<n>`, `_Error<n>`), and the engine takes them as explicit parameters. |

## Known compiler defects

For Mojo 1.2, the owned-capture workaround above also applies to stored borrowed
predicates; mutable access to the closure alone does not preserve those writes.
The following details record the earlier Mojo 1.1 qualification.

Mojo 1.1 can lose writes to an owned mutable closure capture at O3 when a
native callback consumes and returns non-trivial values. A direct binary call
reproduces this independently of the library. `@always_inline` on the callback
avoids the faulty receiver lowering; using a library callable with explicit
mutable receiver storage also avoids this native closure shape. The iterator
expansion ownership tests exercise the annotated closure at O0 and O3.

These are defects of Mojo 1.1.0 reproduced without importing the library. The
library works around them where it can; the remaining forms are excluded from its
supported API.

- **Lost updates at O3.** Calling a closure that owns mutable state through a
  read borrow can lose updates at O3 (a counter that reaches 14 at O0 reaches 12
  at O3; a closure with owned mutable state and a borrowed `String` produces
  `[11, 22]` at O0 and `[11, 12]` at O3). The lazy adapters call stored native
  callbacks through mutable access, and the terminal driver reaches callbacks
  through a typed `Pointer`, which avoids the shape. Closures with owned mutable
  captures are otherwise outside the supported forms; explicit mutable borrowed
  contexts work.
- **Callback convention at O0.** Passing a callable as a `ref` argument corrupts
  some captured layouts at O0. The terminal driver keeps the native read
  convention and passes identity through a `Pointer`.
- **Origin lowering.** Some closures that combine embedded origins with captured
  state fail to lower or crash: a captured closure whose error carries a `Span`
  origin, and a `Span` keyword argument combined with mutable captured state in
  generic forwarding. Argument-carried borrowed views work. Compiler crashes are
  never counted as valid rejections.
- **Owner reassignment.** Replacing the owner of a projected `Variant` while a
  reference into it is still used compiles, and so does moving an owner out
  (`x^`) while a `Pointer` to it is live. Subject stability, and keeping a
  callback that a deferred computation borrows alive until it runs, are
  therefore documented caller preconditions, not checked guarantees.
- **Always-raising scan callbacks** crash the compiler at O3 when the step is
  inlined; `fp.control.scan` keeps its step behind a non-inlining boundary.
- **Function types across modules.** Two modules of one program that spell the
  same function type are given one type, even when the names in it mean
  different declarations. Two modules that each define a `Token` and a closure
  `def(var token: Token) -> Int` fail with `invalid redefinition of 'def(var
  Token) -> Int'`; with a generic parameter, `F: def() -> R` in one module can
  make `F.R` unknown in another. The library's own modules avoid such pairs. A
  program that imports several of its own modules, as the test suite's
  executables do, must give the declarations in colliding signatures distinct
  names.

## Private standard-library spellings

The library uses no non-public standard-library spelling. If one becomes
necessary, isolate it in one private module with a test of the native behavior
it relies on, record the compiler and source revision, and delete it when a
public spelling passes the same test.

## Upgrading the compiler

On each proposed toolchain:

1. Review upstream changes to closures, errors, origins, reflection, `Variant`,
   `Optional`, tuples, packs, iterators and recursion, and the release notes.
2. Recheck each replacement trigger above with a small native program. A newly
   accepted program triggers a design review; it does not broaden the supported
   API by itself.
3. Recheck associated type and error equality, `Never` specialization, closure
   capture and movement, scoped and stable reference lifetimes, constructor
   extraction and package imports.
4. Run every [verification gate](verification.md) through source and package
   imports at O0 and O3, including the compile-time budget.
5. If a native replacement changes type identity, ownership, errors, ordering or
   empty-input behavior, publish it as a named breaking change with a migration.
   Never cast silently between representations.

Mojo 1.2.0.dev2026092305 (eea89a4d) was checked in an isolated environment and
reproduced the closure-return and pack limitations above. That historical probe
is separate from the stable 1.2.0 compatibility migration described above.
