# Selecting native callback contracts before inference

The public `Capture` and `Pipeline` APIs select semantic context before native
callback inference. `Capture[E]` binds argument types, origins and conventions
before `run(callback)`. Direct calls construct a context first,
`Capture[E]().run(callback)`, so E cannot be inferred from the callback. `pipeline(value).raising[E]()` fixes the family and
native error before its operations admit callbacks. The retained legacy
entry points preserve their positional type bindings and adapters.

The [Result tutorial](../tutorial/results.md#bind-arguments-before-the-callback)
and [pipeline reference](../reference/functions.md#select-family-and-native-errors-before-callbacks)
show the supported public calls. The sections below record the experiments
that established this design; their private imports are historical prototypes.

## Production ownership and invocation

A generated finite signature table covers zero to two operands in all read,
mutable and consuming combinations, optionally followed by a native keyword
pack. Its fields use native Pointer origins and owned values. `_BoundThunk`
turns a consumed bundle and borrowed callback into the existing OnceThunk
contract. `attempt_once` and `_attempt_core` own error-to-Result conversion.
Invocation helpers retain literal no-value and Never signatures and reuse the
canonical native helpers wherever that signature already has an owner.

Each bundle invocation consumes its receiver. This gives Mojo responsibility
for cleanup of fields partially moved into a throwing call. It avoids wrapping
every argument in a second optional storage layer. The public native `run`
admission methods inline on 1.2: generic forwarding of a borrowed capture can
otherwise pass the wrong closure storage at O0. This is internal to the native
boundary; callers need no inlining annotation. Direct and generic captured
controls cover every argument shape at both optimization levels.

A selected error does not widen pure or explicit Never calls, including
stateful plain function pointers. The context is constructed before native
admission, and the Never-specific signature excludes the already selected
Never case. Explicit state stays in a library owner and
is passed as `mut State`, preserving updates across success and failure. This
does not repair Mojo's separate optimizer defect for mutation through arbitrary
owned native captures.

Pipeline Result adapters call the existing Result methods with native callback
views. They introduce no branch loops or alternate error handling. Generic
family operations call the family's canonical implementation, preserving its
errors, borrowed origins and deferred evaluation. Changing a stored Result
error also changes the pipeline's ResultFamily.

One callback descriptor generates both family and Result admission signatures.
The family's input type is fixed before a callback is matched. Plain thin
pointers retain their native representation; captured functions use an
origin-preserving reference view. Pure and explicit Never callbacks remain
non-raising inside a selected throwing context, including two-callback stages.
ResultFamily's canonical BindCompatible predicate rejects non-Result outputs
and mismatched stored errors before a bind operation can instantiate its body.

Generic bind wrappers retain a family type parameter (`I: Monad`), optionally
defaulting to `ResultFamily[E]`, and forward `I.BindCompatible[V, F]` together
with `I.Element`, `I.Bound` and `I.BindError`. This keeps dependent projections
abstract until the caller selects a concrete family. Naming `ResultFamily[E]`
directly inside a generic constraint can evaluate its callback-type inspection
too early; `F.Out == Result[U, E]` alone does not prove the complete contract.
The default family preserves ordinary caller syntax. This is a stricter generic
extension contract than the legacy ResultFamily bind check.

Body-only validation was rejected because a callback with a different borrowed
error origin passed it. Signature admission rejects that substitution. The
maintained generic-forwarding and ownership tests exercise the family-parameter
form at both optimization levels, including consuming callbacks.

The maintained native-boundary runner checks source and fresh precompiled
imports at O0/O3, with immutable inventories, raw-log audits and no execution
of rejection fixtures. Compile crashes and timeouts never count as rejection.
The full suite, existing rejections and executable docs remain separate gates.

## Calls and their contracts

| Task | Prototype call | Contract |
|---|---|---|
| Non-raising native chain | `piped(values).filter(predicate).map(transform).get()` | The familiar call shape; List, Optional and Result select their family at construction. |
| Throwing native chain | `piped(values).raising[Failure]().filter(predicate).map(transform).get()` | Select the native error type once before matching callbacks; raised errors keep their exact type. |
| Generic or deferred family | `piped[Family](carrier).map(transform).get()` | The selected family retains its own result, lifetime and execution rules. |
| Non-raising native computation | `attempt(compute)` | A zero-argument callback returns `Result[R, Never]`; explicit `raises Never` is supported. |
| Throwing native computation | `Capture[Failure].run(compute)` | A zero-argument callback raising `Failure` returns `Result[R, Failure]`. |
| Consuming computation | `attempt(work^)` | An existing `OnceThunk` supplies its own output and error types and executes once. |

The complete checked programs live in the experiment's `clients/` directory.
`ordinary.mojo`, `raising.mojo` and `generic_forwarding.mojo` also have current
API counterparts in `baseline/` for compilation comparisons.

Selecting an error type is an additional annotation on previously inferred
valid throwing calls. It replaces compiler-facing signature hints with a
semantic choice, but it does not achieve fewer annotations for every valid
program. Non-raising calls keep their existing shape. Incompatible callbacks
need no `F=type_of(callback)` binding to obtain the tested diagnostics.

`raising[E]()` only selects the admission context for subsequent native
callbacks. It moves the carrier without running it, catching errors or changing
its stored error type. It is not a bound on every error in the chain. A library
callable already declares its error, so the callable overload retains that
type independently of this context. Likewise, `Capture[E].run` preserves
`Never` for a non-raising callback and the declared error of a `OnceThunk`.
A final public API needs a name that communicates this distinction.

## Keep inference separate from execution

Mojo 1.2 can fail while inferring an unknown native error type from an invalid
callback, before a later constraint can reject it. Preselecting the family and
native error type reduces the inference work at the call boundary. Parameters
for callback input and output types are inferred independently, then checked
against the family's contract. This approach still uses native function traits;
it does not depend on unavailable signature reflection.

`Pipeline` has one stored carrier. Its three `map` overloads and four `filter`
overloads adapt native or library callables to the existing family operations.
They introduce no traversal loops, erased callable boxes or new copy
requirements. Deferred operations retain their existing borrow origins.

The overlay also gives zero-argument native invocation one owner,
`callables.native._call_native_thunk`. Both the existing thunk adapters and
Result's native entry points delegate to it. It preserves literal no-value and
`raises Never` signatures at invocation. Plain `raises Never` borrowing
predicates retain their thin function representation through the existing
`_NativeBorrow` adapter. These native representation distinctions stay inside
the adapter layer. `_attempt_core` remains the single owner of converting a
raised error into `Result`.

Moving everything into an unconstrained `F` followed by `conforms_to` was not
enough: that prototype also rejected valid native functions. Splitting the
pipeline into conditional pure and raising types broke generic forwarding.
Adding duplicate literal-`Never` native overloads introduced ambiguity. The
retained design uses one pipeline type and a narrow native invocation boundary.

## Ownership and argument binding

The qualification checks move-only values, exact error payloads, destruction on
success and failure, borrowed and owned captures, and values and errors with
embedded origins. It also checks a ReaderT computation that retains a callback
borrow. Invalid origin substitutions and moving a still-borrowed callback are
rejected. A consuming-only callable cannot be used where List mapping needs
repeated calls.

Native callbacks that mutate owned captures pass the included O0/O3 checks
without `@always_inline`, including callbacks with nontrivial captured values.
That result covers these boundaries and programs; it does not supersede the
broader [native callback limitation](native-boundaries.md#mojo-12-compatibility).

A reusable native closure cannot consume an owned capture. The experiment
retains a native-only rejection client to distinguish that language rule from
library admission. `native_binding.mojo` demonstrates the same computation as
a consuming `OnceThunk`, preserving a mutable borrow, an owned String and a
keyword argument. This preserves the functionality, but writing a callable
struct is more work than a direct native call. Convenient native argument
forwarding, including mixed conventions and keyword packs, remains outside
this slice. The prototype does not yet replace all existing `attempt` forms.

## Argument-binding experiment: not ready to adopt

The follow-up experiment adds the proposed
`Capture[E].mutating(f).run(state)`,
`Capture[E].consuming(f).run(value^)` and
`Capture[E].mut_owned(f).run(state, value^)` forms. It lives separately in
`experiments/mojo12-boundary/binding_boundary.mojo`, installed as
`fp._binding_architecture` only when the runner receives `--bindings`.
`native_boundary.mojo` and production APIs are unchanged.

Each factory fixes the error type and argument convention before accepting
the callback. Its returned wrapper delegates to the existing native reference
adapter and Result argument capture. There are no new execution loops,
exception handlers or user-written callable structs. A fourth factory,
`mut_owned_kwargs`, tests native keyword packs. These are immediate invocation
adapters; stored `.bind(...)` computations have not been implemented.

The source-import pilot on Mojo 1.2.0 established the following results:

| Case | Observation |
|---|---|
| Ordinary mutable, consuming and mixed calls, including typed errors and a keyword pack | Pass at O0 and O3; mutations remain visible after a raised error. |
| Generic forwarding, origin-bearing success/error values and fixed keyword arguments through a native wrapper | Pass at O0 and O3. |
| Incorrect positional convention, arity or error type | All 15 tested clients produce normal diagnostics at O0/O3 without `F=type_of(callback)`. |
| Repeated invocation of a consuming callback that mutates an owned capture | The combined capture test passes at O0 but fails at O3: the second call returns 1 where 2 is required. |
| Incorrect keyword-pack convention or positional prefix arity | Four clients crash the compiler at both O0 and O3. |
| Plain keyword-pack callback returning no value with explicit `raises Never` | A valid call fails native function conversion at both O0 and O3. |

The initial evidence is in
`.cache/mojo12-bindings/pilot-check-1/report.json`. Its negative fixtures
initially expected the phrase `no matching method`; static factories report
`no matching function`. The retained fixtures correct that expectation without
adding type hints or changing the invalid calls. Exploratory runs also exposed
test-fixture mistakes, so their aggregate failure counts are not counts of
library defects. The table identifies the actual semantic and compiler failures.

The first expanded run was interrupted by workspace process exhaustion
(`Resource temporarily unavailable`), with over 16,000 unreaped compiler
crash-handler processes. After reclaiming completed children and supervising
new compiler runs, the full source/package matrix completed reliably:
156/192 checks passed. The report is
`.cache/mojo12-invocation/baseline/report.json`. The failures include the keyword
and capture problems above; four also came from an ownership fixture whose
dictionary lookup could raise an undeclared error. The retained fixture now
translates that lookup error into its declared error type. Aggregate failure
counts are not counts of library defects.

`bindings.json` retains 48 positive and negative clients, including the known
failures. They remain ordinary failing tests, with no expected-crash or
expected-runtime-failure exemption. Reproduce with a fresh output directory:

```sh
pixi run python experiments/mojo12-boundary/qualify.py --bindings \
  --output .cache/mojo12-bindings/review --jobs 1
```

Use a fresh output path if the example path already exists. This syntax improves
positional admission but does not provide the required general reliability.
It should not replace the public API. Capture mutation and keyword-pack
admission require different approaches, tested below.

## Separate explicit state from native captures

Owning the callback and invoking it through a mutable receiver does not resolve
the capture failure. Native-only controls, with no library imports, also lose
owned-capture updates at O3 when the callback parameter is either shared or
mutable. Keeping the callback in an owned library wrapper produces the same
failure for the exact failing callback bodies. Simplified callback bodies can
pass, so those successes alone are insufficient evidence.

`receivers.json` retains eleven controls. Across source/package imports and
O0/O3, 26/44 checks pass; nine clients fail at O3 through both routes. These
remain failing assertions, not accepted failures. A separate pilot passing the
callback by reference through the unary invocation bridge also failed. The
library cannot promise reliable arbitrary mutable owned native captures from
these receiver changes.

The successful alternative gives the library explicit state to own. A plain
native function takes `mut state` as its first argument and a consuming input
as its second. `Capture[Failure].stateful(step, state^)` returns a movable owner;
`work.run(value^)` executes through the existing native adapter and Result
capture kernel. `work.state()` borrows the state and `work^.into_state()` moves
it out. Ordinary state types need no callable protocol implementation.

This changes how users express state: it moves out of an implicit native
capture and into an explicit parameter. The experimental factory accepts only
plain, thin functions; passing a captured callback is rejected. It requires no
user `@always_inline`, preserves updates before a raised error, and can run
again after that error. It consumes each input once, retains the exact error
type, and preserves embedded origins. A state view can remain live across
sequential calls; using it after consuming its owner is rejected. Moving state
through the borrowing accessor is also rejected.

The implementation is isolated in `stateful_boundary.mojo`, installed as
`fp._binding_state` by `--invocation`. It reuses `_OptionalCell`,
`_NativeMutOwnedRef` and Result's existing argument capture. It introduces no
new exception handling or callable execution kernel. This is a qualified
mechanism for explicit state, not a transparent repair of native closures or
a complete replacement for every `attempt` argument convention.

## Stage keyword argument types before callback admission

The follow-up keyword boundary fixes input types as well as the error type
before matching the callback. The experimental call is
`KeywordCall[A, B, K, Failure].of(callback).run(state, value^, **options^)`:
`A` is the mutable argument type, `B` the consuming argument type and `K` the
keyword value type. The output and exact native callback type remain inferred.
All five tested incorrect arity, convention and error-type calls now produce
normal diagnostics without explicit callback type hints or compiler crashes.

`keyword_boundary.mojo`, installed as `fp._binding_staged`, reuses the existing
keyword wrapper, native adapter and Result capture. Plain `raises Never`
callbacks with no return value have a literal thin-signature overload that
stores the function pointer by value. Borrowed mutable captures, including
explicit `raises Never` callbacks, also pass. Mutable owned captures retain
the O3 limitation above.

Both follow-up boundaries need a native invocation distinction: a thin pointer
must be invoked as a thin function, and literal `Never` and no-value signatures
must remain literal. `invocation.patch` adds those cases to the existing
`_NativeMutOwnedRef` and `_NativeMutOwnedKeywordsRef` owners, ahead of their
unchanged closure paths. This is a source-copy overlay; production `src/` is
unchanged by the experiment. No origin or error type is erased.

Prebinding three input types is verbose. It establishes a reliable tested
admission order, not the final public syntax. The argument-first experiment
below derives those types from supplied values before admitting the callback.

## Follow-up qualification

The October 25, 2026 follow-up used Mojo 1.2.0 (2016d0cd), Linux x86-64 and
`--Werror`. Reports below are under `.cache/mojo12-invocation/`.

| Check | Result | Report |
|---|---|---|
| Original 48 binding clients, source/package, O0/O3 | 156/192 pass; known failures remain | `baseline/report.json` |
| Eleven native and owned-receiver controls, source/package, O0/O3 | 26/44 pass; nine clients fail at O3 through both routes | `receivers/report.json` |
| Explicit-state and staged-keyword boundary, 24 clients, source/package, O0/O3 | 96/96 pass: 40 positive executions and 56 rejection checks | `qualification/report.json` |

The passing follow-up checks repeated state updates, error continuation,
move-only state and inputs, destruction, unused owners, state extraction,
generic forwarding, embedded result/error origins, no-value results and
explicit `raises Never`. Rejections cover incorrect signatures and inputs,
captured functions at the plain-function boundary, consumed owners and invalid
origins or lifetimes. Negative clients are never executed, and crashes cannot
satisfy a rejection. All three reports have unchanged inputs during their runs.
The passing qualification has a clean audit; the other two audits flag their
reported failures.

Reproduce the passing follow-up and shared invocation regression checks with:

```sh
pixi run python experiments/mojo12-boundary/qualify.py --invocation \
  --output .cache/mojo12-invocation/qualification --jobs 3
pixi run suite --package .cache/mojo12-invocation/qualification/package \
  --werror --jobs 2 --output .cache/mojo12-invocation/regression-suite
pixi run compile-fail --package .cache/mojo12-invocation/qualification/package \
  --werror --jobs 2 --output .cache/mojo12-invocation/regression-rejections
```

To reproduce the receiver failures, run the same qualification command with
`--receivers` and a fresh output directory. That profile should report its
runtime failures and exit unsuccessfully. Neither those controls nor the
original binding matrix are counted as passing qualification.

## Infer keyword types from argument values

The next experiment replaces the explicit `A`, `B` and `K` type list with
arguments supplied before the callback. Its candidate call shape is
`Capture[Failure].kwargs(state, payload^, extra=3).run(callback)`.
For this slice, the callback takes a mutable first argument, a consuming second
argument and a homogeneous native keyword pack. This is a prototype for that
convention, not a migration of all `attempt` forms.

| Case | Candidate call |
|---|---|
| Nonempty pack, inferred input types | `Capture[Failure].kwargs(state, payload^, extra=3).run(callback)` |
| Empty pack, explicit keyword value type | `Capture[Failure].kwargs[K=Int](state, payload^).run(callback)` |
| Existing typed dictionary, including an empty one | `Capture[Failure].kwargs(state, payload^, **options^).run(callback)` |
| Store arguments before choosing the callback | `var pending = Capture[Failure].kwargs(state, payload^, extra=3)`, then `pending^.run(callback)` |

Construction evaluates the supplied arguments, borrows `state` with its
original mutable origin, and owns the second argument and keyword dictionary.
It does not execute or retain a callback. `run` consumes the bundle and borrows
the callback for that invocation only. Dropping an unused bundle destroys its
owned arguments without calling anything. The state owner must remain alive
until the bundle's last use; results and errors retain their embedded origins.
Argument evaluation occurs before error capture, as with an ordinary function
call. Mutations made by the callback remain visible if it raises.

Ordinary string and integer literals work without type annotations, including
when the bundle is stored in a variable before `run`. Keyword names such as
`first` and `function` are forwarded unchanged. The checked cases also preserve
evaluation order, generic forwarding, move-only values and destruction on
success, error and abandonment. A bundle cannot be consumed twice. Invalid
aliasing with owned arguments or mutable callback captures, moving a still-used
state owner, and substituting incompatible origins produce normal diagnostics.

An empty pack has no values from which to infer `K`. A pilot that inferred `K`
from the callback accepted valid calls but crashed on four incorrect arity or
convention signatures at both O0 and O3. That approach was rejected; its
evidence is in `.cache/mojo12-arguments/pilot-5/report.json`. The retained factory
requires either `[K=...]` or an expanded typed dictionary for an empty pack.
Omitting both gives the ordinary `failed to infer parameter 'K'` diagnostic,
including when the callback itself is invalid. Nonempty packs need neither
the input type list nor `F=type_of(callback)`.

`argument_boundary.mojo`, installed as `fp._argument_staged` by `--arguments`,
owns only this argument bundle. Its native-signature overloads delegate to
`KeywordCall`, the existing native adapter and Result capture. There is no new
execution loop, exception handler, runtime reflection or erased callback box.
This slice also generalizes the existing thin `raises Never` keyword adapter
to valued results, preserving literal thin signatures for both valued and
no-value callbacks. The shared invocation patches are unchanged. Mutable owned
native captures retain the O3 limitation described above; this syntax does not
repair that behavior.

On Mojo 1.2.0 (2016d0cd), the fresh-package qualification passed **232/232**
checks with `--Werror`, source/package imports and O0/O3. This combines the
previous 24 invocation clients with 34 argument-first clients: 92 positive
executions and 140 rejection checks. No negative client executes, and crashes
cannot satisfy a rejection. Inputs remained unchanged and the audit was clean.
The report is `.cache/mojo12-arguments/qualification/report.json`.

Reproduce with fresh output directories:

```sh
pixi run python experiments/mojo12-boundary/qualify.py --arguments \
  --output .cache/mojo12-arguments/qualification --jobs 3
pixi run suite --package .cache/mojo12-arguments/qualification/package \
  --werror --jobs 2 --output .cache/mojo12-arguments/regression-suite
pixi run compile-fail --package .cache/mojo12-arguments/qualification/package \
  --werror --jobs 2 --output .cache/mojo12-arguments/regression-rejections
```

Argument-first binding is the recommended direction for this keyword form:
infer types from values, then admit a callback against that fixed contract.
The explicit empty-pack type is a remaining usability cost. Names, the other
argument conventions and production migration still need review together.

## Qualification on Mojo 1.2

The original, independently qualified boundary slice is described below;
these passing results do not include the argument-binding experiment.
The October 25, 2026 run used Mojo 1.2.0 (2016d0cd), Linux x86-64 and
`--Werror`. All reports below are under `.cache/mojo12-architecture/`.

| Check | Result | Report |
|---|---|---|
| 37 experiment clients, source and fresh package, O0 and O3 | 148/148 pass: 48 positive executions and 100 rejection checks | `review/report.json` |
| Existing positive suite against the patched package, O3 | 332/332 test and example programs pass | `regression-suite/report.json` |
| Existing rejection suite against the patched package, O3 | 712/712 pass | `regression-rejections/report.json` |
| Three equivalent programs, three cold builds per API, O3 | 18/18 compile and execute successfully | `measure-{baseline,prototype}-{1,2,3}/report.json` |

The experiment's 25 negative clients cover convention, arity, input, output,
error, origin and lifetime violations, including the native-only capture
control. No negative client is executed, and compiler crashes or timeouts
cannot satisfy a rejection. All reports have unchanged inputs during their
runs and clean audits. The experiment additionally records its own source
hashes and the copied library's hashes.

The existing rejection suite still includes the 22 explicit callback bindings
described in [rejection diagnostics](native-boundaries.md#rejection-diagnostics).
Passing that suite checks for regressions in shared invocation; it does not
show that every affected production API has been redesigned. The new
experiment clients separately check invalid calls without those hints.
Diagnostics include normal overload mismatch notes and origin mismatches;
they are not custom library explanations.

Cold compilation showed no increase for the three measured clients. The
[compilation observations](performance.md#mojo-12-boundary-prototype) record
timings, memory and their limits. This is sufficient evidence to continue the
design, not evidence of whole-library compatibility or a general performance
improvement.

## Reproduce the experiment

Run from the repository root with the pinned Pixi environment. Each output
directory must be new. The production gate is `pixi run boundaries-test`;
the older isolated prototypes can still be reproduced below.

```sh
pixi run python experiments/mojo12-boundary/qualify.py \
  --output .cache/mojo12-architecture/review --jobs 3
pixi run suite --package .cache/mojo12-architecture/review/package \
  --werror --jobs 2 --output .cache/mojo12-architecture/regression-suite
pixi run compile-fail --package .cache/mojo12-architecture/review/package \
  --werror --jobs 3 --output .cache/mojo12-architecture/regression-rejections
```

The runner uses the repository's shared compilation, execution and audit
helpers. It creates an isolated source tree and fresh package, validates the
declared client inventory, and fails if any checked input changes during the
run. It never edits `src/`.

## Further migration

Capture and the selected Pipeline boundary are public. The original APIs
remain compatibility entry points; passing their rejection tests does not
prove all their invalid inferred calls diagnose normally. Further migration
of traversal, n-ary operations and iteration should retain the same admission
rule and qualify original invalid calls beside valid counterparts. It must
continue to reuse family and callable execution owners.
