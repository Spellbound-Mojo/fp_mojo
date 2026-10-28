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
- Stored thin pointers need explicit register or memory evidence at `as_unary`
  and `as_binary` admission, just as Capture does. The factories share that
  signature policy.
  Borrowed callback views call their native helpers directly: an extra
  function-valued dispatch policy can corrupt Bool results at O0. The
  [current architecture](mojo12-redesign.md#native-signatures-and-storage)
  describes the shared boundaries and their regression coverage.
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
- Stored native pointers with homogeneous keyword packs retain the pack name
  in their type. Mojo 1.2 rejects conversion between `**options` and `**kwargs`
  even in a native-only client. Capture's stored-pointer type uses `**kwargs`;
  the function declaration may retain its own spelling. The maintained
  `capture_native_abi_keyword_name` fixture records this normal compiler
  diagnostic separately from the library's ownership and error rejections.
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

The production Capture and Pipeline APIs select family and native error context
before callback inference. Their maintained invalid-call clients need no explicit
callback-type hints. The [current compatibility inventory](../guides/compatibility.md)
records the verified production checkpoint, scope and pending migration.

The sections below preserve earlier qualification evidence and the legacy
restrictions that remain relevant. Their test counts are historical checkpoints,
not the current suite inventory. The [redesign history](mojo12-redesign.md)
records the experiments and the promoted architecture.

### Rejection diagnostics

#### Current API-quality audit

The October 26, 2026 audit at `09f1664` rechecked all 31 rejection fixtures
containing a literal `F=type_of(...)`, `C=type_of(...)` or `G=type_of(...)`
binding. Removing just that binding reproduced a compiler crash in all 31
source-import probes at O0 on Mojo 1.2.0 (2016d0cd). Of these, 21 bind `F`,
nine bind `C`, and one binds `G`. This count includes later `attempt` selector
fixtures; it is not the historical 22-fixture inventory below. Generic forwards
using a symbolic binding such as `F=F` were not part of this removal audit.

A small reproduction needs no FP import. The maintained
[inferred-error client](https://github.com/Spellbound-Mojo/fp_mojo/blob/nightly/experiments/mojo12-diagnostics/inferred_error.mojo)
passes a consuming callback to a function requiring a borrowing callback.
The paired
[selected-error client](https://github.com/Spellbound-Mojo/fp_mojo/blob/nightly/experiments/mojo12-diagnostics/selected_error.mojo)
keeps the same invalid convention and fixes only the expected error type.
Both clients are intentionally invalid; the inferred variant records an
unresolved compiler failure under `experiments/`.

```sh
pixi run mojo build -O0 --Werror experiments/mojo12-diagnostics/inferred_error.mojo
pixi run mojo build -O0 --Werror experiments/mojo12-diagnostics/selected_error.mojo
```

The invalid call crashes while inferring the native signature. Replacing
`raises E` with `raises Int` and removing the unused `E` parameter gives a normal
`value passed to 'function' cannot be converted` diagnostic. An overload pair
with separate pure and generic-raising candidates also crashes. Fixing only the
input/result types, defaulting `E` to `Never`, or adding an unconstrained
diagnostic fallback did not repair the tested failures. These observations
identify an inference boundary; they do not establish the compiler's internal
root cause or prove that every possible native encoding fails.

The production solution selects the family, argument conventions and native
error context before callback admission:

| Use | Preferred boundary | Evidence without callback-type bindings |
|---|---|---|
| Container predicates and transformations | `pipeline(values).filter(predicate)`; use `.raising[E]()` before a raising native callback | `context_filter_owned.mojo`, `context_filter_owned_raising.mojo` |
| N-ary combination | `pipeline(value).map_n(others, callback)` | `context_native_nary_arity.mojo` |
| Mutable native capture | `Capture[E].mutable(value).run(callback)` | `capture_m_convention.mojo` |
| Observers and effectful queries | Selected Pipeline `pair_with`, `traverse_tap`, `all_effect` | `context_observers_pair_with_thin_owned.mojo`, `context_effect_queries_all_effect_convention.mojo` |

These APIs preserve their documented ownership and error contracts. A selected
native error does not replace a family's or library callable's error. Passing a
native callback directly to Pipeline also avoids unnecessary `as_unary`
promotion; code that actually needs an owned `Unary` still uses that factory.
There is no new diagnostic guarantee for invalid `as_unary` calls.

This pass retains the legacy signatures and their explicit-binding controls.
Changing execution helpers cannot fix a crash that occurs before a body is
selected, and silently dropping error inference would break valid legacy calls.
The ordinary selected rejection clients remain separate tests; a successful
explicit-binding control is never counted as an ordinary-call fix. The local
removal audit is in `.cache/quality/{diagnostics,result-diagnostics}/report.json`;
the [cold-build comparison](performance.md#mojo-12-api-quality-passes) records
selected diagnostics and valid examples with independent empty caches.

The same production source passed 632 programs/examples and all 1,385 declared
rejection fixtures through fresh precompiled packages at O3 with `--Werror`.
The focused `context_filter`, `context_native_nary` and `capture_m_` inventories
also passed all 116 source/package checks at O0/O3. Each report has unchanged
inputs and clean audits. Reports are in `.cache/quality/final-suite/`,
`final-rejections/`, `final-context_filter/`, `final-context_native_nary/` and
`final-capture_m_/`. The full rejection count includes the legacy explicit-binding
controls; it does not imply that every invalid inferred native call diagnoses
normally.

#### Historical explicit-binding checkpoint

The 22 remaining convention and arity fixtures now bind the callback's existing
native type parameter explicitly. The invalid callbacks and their original
expected diagnostics are retained. Each fixture additionally requires a
`value passed to 'F' cannot be converted` diagnostic (or `C` / `G`, as applicable),
so an unrelated overload or parameter-name error cannot satisfy the test.
Compiler crashes and timeouts still fail; negative clients are never executed.

This is a diagnostic workaround in the tests, **not a transparent fix for the
compiler's invalid-call inference**. Removing the explicit callback type from
these fixtures reproduces the Mojo 1.2 crash. The library's public API and valid
inferred calls are unchanged. As with an incompatible `attempt` selector, an
explicit type lets the compiler reject the bad signature during parameter
binding, before runtime-operand inference:

| Existing parameter | Boundaries covered by these fixtures |
|---|---|
| `F=type_of(callback)` | `mutating`, `as_unary`, Piped `pair_with`, `map_n`, `filter`, `filter_not`, `filter_effect`, `traverse_tap`, and Iterated `all_effect` |
| `C=type_of(callback)` | Result and Piped projection, recovery and observer callbacks |
| `G=type_of(factory)` | Piped `ensure` error factory |

`tests/integration/test_native_rejection_bindings.mojo` supplies valid
counterparts with the same explicit bindings, checking mutable input updates,
retained owned payloads, tuple handling, effectful traversal and Result branches.
The targeted matrix also compiles and runs a minimally corrected counterpart
for each of the 22 negative clients. All 180 checks pass through source and
fresh package imports at O0/O3 with `--Werror`, with unchanged inputs and clean
audits (`.cache/mojo12-rejection-binding/qualification/report.json`).

That earlier checkout passed these complete gates on Mojo 1.2.0 (2016d0cd),
Linux x86-64, with `--Werror`:

| Check | Result | Report under `.cache/mojo12-rejection-binding/` |
|---|---|---|
| All rejection fixtures, fresh package at O3 | 712/712 pass; zero crashes, unexpected acceptances, executions or audit failures | `compile-fail/report.json` |
| Full positive suite, the same package at O3 | 332/332 programs pass; zero audit failures | `suite/report.json` |
| All 57 documentation examples, source/package at O0/O3 | 228/228 checks pass | `docs-examples/report.json` |

All three reports have unchanged inputs. The rejection result qualifies the
explicitly bound fixtures; it does not qualify the original unhinted invalid
calls. The source snapshots and failing reports from before this workaround
remain in `.cache/mojo12-rejection-binding/original/` and
`.cache/mojo12-remaining/compile-fail/report.json`. The fixture comments identify
the binding to remove when checking whether a future compiler fixes inference.

The observer and inference results below record the preceding checkpoint;
its 22 failing rejection fixtures are the ones updated here.

### Observer storage and exact callback inference

The October 25 compatibility pass preserves the admitted borrowing signature in
lazy observer storage, using the existing inline optional cell. This keeps its
native destruction witness when the callback returns an origin-bound value.
Lazy calls retain mutable access to owned captures. No-value calls recover the
literal native signature, including the register-argument form; eager calls
reuse the existing register dispatcher. The regression exercises pointer
identity, repeated pulls, abandonment before the first pull, capture mutation
and exactly-once destruction.

Native Result `map_err`, `or_else`, `fold` and `fold_owned`, terminal folds and
predicates, lazy `scan_left` and `filter_map`, native loop results and Piped
filter results now infer callback types before checking exact equality with the
requested types. Invocation uses the actual native signature. The shared fold
bridges adapt only types whose equality is established by the public constraint;
origins, ownership, evaluation order, cleanup and exact errors remain unchanged.
Existing positional callback/error bindings and named requested result types
are retained. Generic user forwarders may need the same separation to diagnose
invalid calls: infer the actual result as `R`, then require
`R == Optional[U]`, for example.

Three combined rejection fixtures were split so the compiler checks each bad
call independently. Seven fixtures now expect the constraint diagnostic that
replaces their former inference crash. Five positional-family fixtures retain
their original call and check Mojo 1.2's ambient-error diagnostic; five companion
fixtures bind `I=` and check the intended family constraint. A positional family
type can also bind the native error parameter of a Result-specific overload.
This diagnostic ambiguity does not require changing valid positional calls or
restricting the set of native error types.

Full compatibility remains incomplete. Some invalid argument conventions and
callback arities still crash during overload inference. An incompatible
`attempt` selector still needs `F=type_of(callback)` for a normal diagnostic;
the supported convention selectors and four adapters are unchanged. Compiler
crashes remain failing tests, and rejection clients are never executed.

Targeted qualification on Mojo 1.2.0 (2016d0cd), Linux x86-64, passes with
`--Werror` through source and package imports at O0/O3:

| Coverage | Result | Report |
|---|---|---|
| Callback inference, origins, ownership, lazy observers and positional bindings | 432/432 checks pass | `.cache/mojo12-remaining/qualification-v3/report.json` |
| Positional and named-family rejection diagnostics | 40/40 checks pass | `.cache/mojo12-remaining/family-qualification-v2/report.json` |

Both reports have unchanged inputs and clean per-case audits. The promoted
library also passes the following complete gates:

| Check | Result | Report under `.cache/mojo12-remaining/` |
|---|---|---|
| Positive suite, fresh package at O3 with `--Werror` | 331/331 programs pass; zero audit failures | `suite/report.json` |
| Rejection suite, the same package at O3 with `--Werror` | 690/712 pass; 22 compiler crashes | `compile-fail/report.json` |
| All 57 documentation examples, source/package at O0/O3 | 228/228 pass | `docs-examples/report.json` |
| Source and precompiled package builds | Both precompile and run the native core client successfully | `build-source/report.json`, `build-precompiled/report.json` |
| Python tooling | 36/36 tests pass | `tooling-v2.log` |

The rejection failures fell from 58 to 22, with no newly failing fixture.
All 22 are compiler crashes: 19 involve wrong native argument conventions and
three involve callback arity or tuple unpacking. No negative client was
unexpectedly accepted or executed. The rejection audit reports two entries per
crash; there are no unrelated audit failures or input changes. The remaining
fixture inventory is `.cache/mojo12-remaining/remaining-rejection-failures.json`.
The separate unhinted-selector reproducer still crashes against the promoted
package (`selector-without-hint/report.json`); the explicit-`F` diagnostic
fixtures pass in the rejection suite.

### Earlier qualification checkpoints

The following checkpoints record earlier stages of the migration. Their
remaining-failure counts are superseded by the results above.

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

The earlier source report is `.cache/mojo12-source-o0-o3-4/report.json`:
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
The Result bridge transfers one consumed argument bundle from
`callables._arguments` through `_BoundThunk` and `attempt_once`, sharing
Capture's storage, origins and invocation. The pending callable uses one
`Optional` cell; `data._attempt._attempt_core` owns success/error capture.
Native invocation delegates to `callables.native`, including the literal
no-value and explicit `Never` signatures required by Mojo 1.2. The shared
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

### Compile-time convention selectors

`attempt` and `attempt_kwargs` support an optional named compile-time selector,
for example `attempt[owned_mut=True](function, first^, second)`. Only the
owned/mutable native overload pair declares that parameter name. In the tested
calls, unrelated families are excluded before incompatible native-signature
inference can crash. The selector is appended after existing parameters, so
the positional `F` binding is preserved. The selector must be `True`; a signature
constraint rejects `False`. Existing adapters remain supported. Selection does
not change callback borrowing, argument ownership, origins, evaluation order or
the exact result/error types. The following experiments established the design
before its promotion into the library.

The library-independent pilot passes correct read, mutable and owned selectors
at O0/O3, including a generic consuming forwarder and a captured read callback.
The same consuming forwarder crashes without a selector. Supplying `E=Never`
also fixes that small reproducer; this does not establish error hints as a
general replacement for convention selection. Unknown selector names receive
normal diagnostics, but selecting an incompatible existing convention still
crashes the compiler.

Adding selectors to copies of the twelve remaining `attempt` modules restores
seven at O0. Adding selectors at their overloaded `capture` and `forward`
boundaries restores two more. A library hint cannot repair inference that
already fails in the caller's own overload set. These copies also replace the
four existing adapters with direct selected calls, exercising the proposed
alternative without changing the original test sources.

Selection exposes separate no-value and explicit `Never` invocation failures.
A second prototype routes owned unary calls through `_call_native` and mutable
unary calls through `_NativeMutatingRef.invoke`. A private mutable/keyword view
uses the same literal-signature handling as the existing mixed keyword view.
These six overload-body adjustments restore two further modules. They are
invocation changes in addition to the selector experiment, not evidence that
selector parameters alone resolve all eleven modules.

The final `.cache/mojo12-attempt-selectors/qualification-v2/report.json`
precompiles the prototype package with `--Werror` and records:

| Scope | Source/package at O0/O3 |
|---|---|
| Twelve affected modules, with selectors and invocation adjustments | 44/48 runs pass; eleven modules pass in every combination |
| Ten unchanged controls, including adapters and inferred/positional bindings | 40/40 runs pass |
| Selected calls with external result/error origins and positional `F` bindings | 4/4 runs pass |
| Seven rejection clients | 24/28 checks pass; selecting the wrong convention crashes in all four combinations |

All inputs stayed unchanged during qualification, and every passing case has
a clean audit. Rejections cover use-after-move, mutable aliasing, captured
aliasing, read-only inputs, incompatible error origins and unknown selector
names. No rejection client is unexpectedly accepted or executed.

The remaining positive failure at this checkpoint was
`integration/test_attempt_forwarding.mojo`: a captured no-value callback with
a default-convention `Int` argument loses its native closure witness. Separate
O0 probes reproduce this through the existing `consuming` adapter as well as
the selected call. Explicit `var Int` callbacks pass, with either an omitted
result annotation or `-> None`. Direct admission through a literal no-value
signature also passes; forwarding from the generic `-> R` signature does not.
This narrows the remaining investigation to retaining native signature evidence
and does not justify changing the callback's public convention.

Scalar default arguments use the native owned signature family, and overloaded
user forwarders may need their own selectors. The promoted signatures validate
the Boolean value, unlike the original prototype. Neither these selectors nor
their focused qualification resolves the separate lazy observer failure or
establishes complete library compatibility.

### No-value register arguments and selector diagnostics

The shared owned unary dispatcher now preserves the register convention when
recovering a native no-value signature. A default `Int`, `Float64` or `Bool`
argument is passed in a register, whereas rebuilding `def(A)` with only a
generic `Movable` bound describes an argument passed in memory. The latter
signature can lose the callback's native closure witness on Mojo 1.2.

For a `TrivialRegisterPassable` argument, the dispatcher retains that bound
when checking and invoking the callback's literal no-value signature. Pure,
typed-error and explicit `Never` paths share `_call_native_register_void`.
The existing memory convention remains available for callbacks that use it.
No public signature, callback convention, ownership rule or result/error type
changes. In particular, a native no-value result remains distinct from
`NoneType`. Both this fix and the selector API are in the library.

`ownership/test_native_register_void.mojo` covers two generic forwarding
layers, reusable borrowed adapters, stored move-only captures, destruction
counts, default scalar arguments, mutation before an error, exact inferred
errors, thin functions, `NoneType` and explicit `Never` through `pipe`.

The promoted dispatcher passes all forty focused checks against the actual
library: seven positive modules and three ownership/origin rejection fixtures,
each through source and package imports at O0/O3 with `--Werror`. Package
precompilation succeeds, inputs remain unchanged during the run, and all audits
are clean. The report is
`.cache/mojo12-attempt-followup/canonical-qualification/report.json`.

The updated selector prototype was qualified with `--Werror` at O0/O3 through
source and package imports in
`.cache/mojo12-attempt-followup/qualification/report.json`:

| Scope | Result |
|---|---|
| All twelve affected modules | 48/48 runs pass |
| Fifteen existing controls | 60/60 runs pass |
| Register-argument and origin/positional-binding regressions | 8/8 runs pass |
| Seventeen rejection clients | 64/68 checks pass; the four failures remain wrong-convention compiler crashes without an explicit callback type |

Inputs remained unchanged and passing cases have clean audits. No rejection
was unexpectedly accepted or executed. These historical results include the
prototype's previous selectors and invocation changes, not just the register
fix. Those selector and invocation
changes are now promoted together; permanent tests retain all twelve affected
modules, positional bindings, origins and the diagnostic workaround.

There is a tested diagnostic workaround for an incompatible selector:
`attempt[mutable=True, F=type_of(function)](function, value)`. Supplying `F`
explicitly moves its validation into parameter binding, before runtime-operand
inference; the pinned compiler's
[inference order](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/lib/MojoParser/ParamInf.cpp#L1858)
explains the distinction. All forty checks of ten explicit-type rejection
clients pass, covering pure, typed-error, `Never`, captured, binary, keyword,
no-value and generic callbacks. Valid calls can continue to infer `F`.

This does not make a wrong selector without the hint diagnose normally. Late
constraints, deferred signature parameters, extra literal no-value overloads,
trait composition and equality-based admission either still crash or reject
valid calls in the isolated probes. Scalar-specific public overloads were also
discarded. The library has no proven transparent guard for this compiler bug;
the original rejection remains a failing check. Compiler and standard-library
changes are outside the project scope, and the separate lazy observer failure
has not been resolved by this work.

### Promoted selector qualification

The selectors and six native invocation adjustments are now implemented in
the library. All 52 native signatures retain their existing parameters and
positional bindings, with a distinct optional selector appended at the end.
The new signature constraints reject `False`. The twelve affected modules
now call the supported selectors; their assertions and expected values are
unchanged. Existing adapters remain covered by unchanged control modules.

Mojo 1.2.0 (2016d0cd), Linux x86-64, with `--Werror`:

| Scope | Result | Report under `.cache/mojo12-attempt-promotion/` |
|---|---|---|
| Twelve affected modules, fifteen controls, two ownership/origin regressions and twenty rejection fixtures, source/package at O0/O3 | 196/196 checks pass | `qualification/report.json` |
| Seventeen older rejection fixtures migrated to selectors without changing expected diagnostics, source/package at O0/O3 | 68/68 checks pass | `rejection-qualification/report.json` |
| All 57 documentation examples, source/package at O0/O3 | 228/228 checks pass with their reviewed output | `docs-examples/report.json` |
| Full positive suite at O3, excluding diagnostic benchmarks | 328/329 programs pass when combined with the focused checks and separate verification of the blocked batch | `suite/report.json`, `blocked-batch/report.json` |

The full suite's runtime-1 batch cannot build because
`test_combinator_expansion.mojo` still loses its lazy observer destruction
witness. Twelve other programs in that batch pass in the focused matrix;
the remaining 47 pass in separate package builds. The other three batches
pass all 269 checked programs. Inputs stayed unchanged during each run, and
every passing case has a clean audit. Strict documentation and API checks pass.

The initial full rejection gate passes 629/704 fixtures. All 75 failures also
reproduce against the library before selector promotion, with the same
classification: 70 compiler crashes and five diagnostic mismatches
(`baseline-rejections/report.json`). Seventeen of those fixtures now select
their native convention and pass all four rechecks. Combining those results
leaves 58 existing failures: the known incompatible-adapter crash and 57
fixtures outside `attempt`. The original full rejection report remains failed;
these failures are not counted as successful rejections. No invalid client
was accepted or executed.

An incompatible selector without an explicit `F` hint also still crashes in
the promoted package; `known-compiler-issue/report.json` retains that failure.
The explicit-`F` workaround is covered by permanent rejection fixtures. This
promotion restores the twelve positive modules without claiming complete
Mojo 1.2 compatibility.

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

That migration pass also updated 45 calls in nine existing test modules to
the four approved `attempt` adapters. Those modules still contained other
conventions, including one-prefix keyword callbacks and additional binary
combinations, so migration of those calls alone did not qualify whole modules.
An exploratory invalid `Continue`-payload origin case also still crashes during
inference; it is not counted as a successful rejection. The stored no-value
`as_unary` limitation and generic terminal predicate conversion failure were
separate from the one-stage pipeline fix; the next pass below addresses them.

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

### Scan admission and remaining native callback boundaries

Native `scan` and `scan_map` now infer the entire callback result as `R`, then
constrain `R == Tuple[A, Y]` in the public signature. This avoids the Mojo 1.2
crash while inferring the tuple pack inside a native return type. The eager
bridges retain that same admitted `R` and rebind only under the equality
constraint. Explicit `raises Never` steps use the canonical native binary
dispatcher, preserving its literal error signature. The existing carry transition, scheduler, iterator driver and
cleanup paths are unchanged. Native inferred calls, `scan`'s positional
unroll/length bindings, `scan_map`'s positional type bindings and library
`Binary` calls remain available. Generic forwarding helpers that admitted
`F: def(var A, var X) -> Tuple[A, Y]` need the same whole-result spelling and
may need to pass `Y=Y` when forwarding the still-symbolic result.

Stored native callbacks with no return value now have literal thin admission
in `as_unary`, and the canonical unary dispatcher preserves their no-value
thin signatures. This is distinct from a callback explicitly returning
`NoneType`. Both remain supported, as do pure callbacks, typed errors and
explicit `raises Never`. Tests exercise copied plain callbacks, moved inputs,
repeated calls, borrowed and moved-out access, and move-only captures with
exact destruction counts.

`find`, `any` and `all`, including their fluent forms, now preserve plain
raising predicates as thin functions. This avoids Mojo 1.2's failing
thin-to-closure conversion when the caller explicitly binds `E=Never`.
A small thin invocation bridge feeds the existing terminal drivers. The
generic closure overloads and their positional `F` binding remain available.
User-written generic forwarding layers that admit plain functions also need
a thin overload if they explicitly bind `Never`; changing only the library
cannot repair a conversion that fails before reaching it. Integration tests
exercise two such layers, and separate tests retain captured predicates.

The separate lazy observer problem involving a callback that borrows an owner
and returns a span into it remains unresolved. Storage-only experiments did
not preserve both invocation and destruction witnesses and were not promoted.
The remaining `attempt` modules were subsequently restored by the convention
selectors above; the existing four adapters remain in place.

Verification for that earlier checkpoint:

- `.cache/mojo12-rest/source-matrix/report.json` passes 256/269 test modules at
  both O0 and O3. The same 13 modules fail at both levels: twelve `attempt`
  modules still encounter unsupported native convention combinations, and
  `test_combinator_expansion` encounters the lazy observer destruction witness.
  This checkpoint preceded the final explicit-`Never` scan dispatch change.
- `.cache/mojo12-rest/qualification/report.json` precompiles the package with
  `--Werror` and passes 54 positive package runs, 68 source/package rejection
  checks and 16 example runs, all at O0/O3.
- After adding the explicit-`Never` scan fix and its ownership test,
  `.cache/mojo12-rest/final-followup/report.json` precompiles the final package
  and passes all 32 positive runs, 24 rejection checks and four example runs
  across source/package and O0/O3. The scan tests include distinct external
  origins, incompatible carry/output origins, positional bindings, native
  generic forwarding, moves and destruction counts.

Every report records unchanged inputs, and every passing case has a clean
audit. Documentation, generated API/export metadata and all 36 tooling tests
pass. This is still partial Mojo 1.2 qualification: the remaining modules and
other previously recorded rejection crashes are not counted as successes.

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

Native collection storage access is isolated in
`fp._internal.native_collections`; algebra operations delegate conversions to
it and retain their existing callback/error loops. The boundary is qualified
against Mojo 1.2.0 (`2016d0cd`) and the matching standard-library source at
[revision 527d069](https://github.com/modular/modular/tree/527d069ee11a41ac5320af1f9402db0a66b2b868/Mojo/stdlib/std/collections).

| Dependency | Why it remains | Replacement trigger |
|---|---|---|
| Deque `_capacity`, `_min_capacity`, `_maxlen`, `_shrink` | The public constructor accepts these settings, but there are no public getters. Transformations must preserve allocation/shrink policy and bounded eviction. | Public configuration accessors that pass the same settings and eviction checks. |
| StringDict `_dict` | Whole-storage transfer preserves key order, hasher type and move-only payloads without copying or reinserting entries. The source field is reinitialized before destruction. | Public owning conversion to/from the backing Dict with the same ownership and cost. |

StringDict has a public `deinit_with` that moves entries through a non-raising
callback. It does not transfer the backing Dict intact; using it with the
current fallible iterator driver would require rebuilding intermediate storage
or a different shared accumulation protocol. Borrowing `items`/`values` also
requires Copyable values. These are not equivalent replacements for the
current conversion boundary.

`test_context_collection_storage.mojo` qualifies configuration and eviction,
empty storage, insertion order, hasher type, move-only destruction, partial
failure cleanup and borrowed origins through source/package imports at O0/O3.
The existing native container mapping/filtering tests cover its consumers.

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
