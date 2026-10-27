# Mojo 1.2 contracts and next work

`Pipeline` and `Capture` select semantic context before native callback
inference. They adapt native signatures to existing execution owners while
preserving exact types, errors, origins and ownership. This page describes the
production architecture on `nightly`, pinned to Mojo 1.2.0 (2016d0cd).

The [compatibility inventory](../guides/compatibility.md) records qualified
scope and retained limitations. The earlier experiments and migration history
remain available in the [archived version of this page](https://github.com/Spellbound-Mojo/fp_mojo/blob/51e0ef40a141beb352bf47fb27cf3c4fb5913b6e/docs/content/architecture/mojo12-redesign.md)
and `experiments/mojo12-boundary/`. Their private APIs and trial call spellings
are historical evidence.

## Public calls

| Task | Supported call shape | Contract |
|---|---|---|
| Select a native family | `pipeline(value)` | Native carriers select their dictionary; custom semantics use `pipeline[Family](value)`. |
| Admit throwing native callbacks | `pipeline(value).raising[Failure]()` | Select the native error context before callback inference. Stored Result errors remain independent. |
| Capture a zero-argument call | `Capture[Failure]().run(callback)` | Construct the context first; pure and explicit Never callbacks retain Never. |
| Bind consumed operands | `Capture[Failure].args(first, second).run(callback)` | Bind zero to two owned operands and consume the pending call once. |
| Bind mixed ownership | `Capture[Failure].mutable(state).take(value).run(callback)` | Bind each read, mutable or consuming convention explicitly before matching the callback. |
| Bind a native keyword pack | `Capture.args(value).kwargs(key=option).run(callback)` | Own a homogeneous pack; an empty pack needs its type or a typed dictionary. |
| Repeat a stateful native call | `Capture[Failure]().stateful(step, state)` | Own the explicit state and function pointer; `run(input)` retains mutations after captured errors. |
| Fold in a selected effect | `pipeline(values).fold_effect[Target](initial).run(step)` | Fix the accumulator and target before inferring the mutable or consuming step. |

These are call shapes, not additional wrappers or replacement execution
engines. The [Result tutorial](../tutorial/results.md#bind-arguments-before-the-callback)
and [selected pipeline reference](../reference/functions.md#select-family-and-native-errors-before-callbacks)
provide executable examples. Existing `attempt`, `attempt_kwargs`, adapters,
Result methods, free functions and `Piped` retain their supported bindings.

A selected native error context is not an error bound on every operation.
Library callables declare their own errors. A deferred family can have distinct
construction and execution errors. Pure and explicit `raises Never` callbacks
remain non-raising in a throwing context. Different inhabited errors require an
explicit common mapping; matching memory layout is not type identity.

## Execution owners

| Responsibility | Canonical owner | Boundary responsibility |
|---|---|---|
| Callback receiver dispatch | `callables.protocols`, `callables.native` | Preserve shared, mutable and consuming contracts and exact callback origins. |
| Native argument storage and invocation | `callables._arguments` | Own borrowed pointers, consumed fields and consuming transitions independently of error selection. |
| Native errors stored as Result | `data._attempt._attempt_core`, `attempt_once` | Bind a consumed argument bundle through `_BoundThunk`; never duplicate catching logic. |
| Mapping, binding and products | The selected family and existing Applicative product runner | Adapt the native callback and forward the family's output and error projections. |
| Native source normalization | `iteration._advance` | Retain ownership, iterator position and the existing Array buffering boundary. |
| Folds and traversal | Existing iterator and algebra drivers | Admit a source and continuation; preserve pull order, early stop and cleanup. |
| Deferred computation | Reader, State, Writer and transformer endpoint owners | Preserve construction versus execution timing and origin-indexed output types. |
| Filtering's resulting family | `FilteredFamily` and `MapFilteredFamily` | Continue in the declared output dictionary; NonEmptyList filtering becomes List. |

Custom dictionaries retain their semantics. A Result representation selected as
Validation does not acquire Monad sequencing merely because its storage is a
Result. `flat_tap`, `flat_pair_with`, `before` and `followed_by` use the selected
Monad's bind, including its branching, short-circuiting and deferred behavior.

## Admission and generic extension

Admission belongs in signatures when an invalid callback, carrier or origin
could otherwise reach unsafe inference. Body-only assertions do not establish
an origin contract: a returned error can borrow a different owner even when
its apparent payload shape matches.

Families expose carrier and operation predicates such as `CarrierCompatible`,
`MapCompatible`, `BindCompatible` and `TraverseCompatible`. Traversal admission
is distinct from mapping: a native List dictionary can traverse owned iterable
sources while mapping still requires a List. Deferred dictionaries validate
their base carriers and inner payloads through the same predicates used by
public operations.

`ReaderFamily`, `StateFamily` and `WriterFamily` expose generic execution
contracts. Reader's `RunCompatible[V, o]` checks the actual run origin;
`EndpointCompatible[T, F]` validates endpoint construction. A finite set of
witness origins is not proof for every Reader output. Writer's `Unwrapped[V]`
and `unwrap` retain its base result abstractly while delegating ownership to
the existing Writer value.

Generic wrappers keep a family parameter, for example `I: Monad`, and forward
its compatibility predicates and dependent result/error projections. A
concrete `ResultFamily[E]` expression inside a generic constraint can expand
callback inspection too early on this compiler. Abstract family parameters
avoid that premature expansion; concrete callers still infer the ordinary
call shape. Input equality and carrier membership have separate owners and
must not be repeated in ways that prematurely reduce dependent projections.

MapContract, BindContract and TraverseContract in `algebra.contracts` own the
checked operation's compatibility, output and exact construction-error
projections. Selected map, flat_map and traverse use these descriptors, and
generic clients can forward their complete `Compatible` predicate. Component
predicates remain separate so native admission can supply input equality while
family checks stay opaque. Family primitives still own invocation and deferred
evaluation; no operation object, storage box or extra function-valued dispatch
layer is introduced. Existing free-traversal admission is preserved through
the contract's individual input and collection projections.

FilterContract groups exact borrowed-payload equality and the Bool predicate
requirement. Its optional inversion selects the actual family predicate before
projecting output and error, preserving predicate-dependent family effects.
CombineContract separates callback operand equality, left/right carrier
membership and the family's combination predicate. Selected map2 consumes the
family and carrier predicates together. Legacy map2_lazy still requires only
OperationCompatible, so existing generic wrappers keep their admission policy.
These contracts add no receiver adapter or execution layer. Folds continue to
use their existing source and receiver contracts; new descriptors are added
only where a client otherwise repeats operation-specific proofs.

All operation contracts name their fluent output family. Generic return types
can project Family/Out/Error consistently instead of reconstructing selection.
FilterContract.Family is a lazy Functor projection: standalone filtering never
requires it, so independent Filterable implementations remain supported.
Fluent filtering keeps the explicit FilteredFamily conformance proof beside
Compatible. On Mojo 1.2 a combined boolean alias cannot substitute for the
existing expanded signature conditions in both directions; no redundant
fallback overloads or weakened constraints are introduced to hide that limit.
FilterMapContract.Compatible exposes selected input equality only, retaining
family-owned representation/receiver checks and existing free-function admission.

Terminal and traversal syntax share `scripts/operation_specs.py`. It owns
callback mode, retention and postprocessing choices, associated result/error
expressions, and existing execution targets. Selected Pipeline and legacy
free/Piped/Iter emitters keep their own inference barriers, parameter order
and admission strength. Sharing an operation policy must not add a selected
constraint to a legacy generic forward. This extraction preserves every
generated Mojo byte; the existing generator-parity checks cover both surfaces.

Result, legacy Piped and selected Pipeline also share ResultOperation descriptors
in `operation_specs.py`: callback ownership, payload/argument roles, conditional
continuation results, output carriers and native error combination spelling.
Each emitter retains the native evidence available at its boundary, including
when literal Never can simplify a generic error. Result-specific inference
exceptions and positional bindings stay local; the descriptor never adds a
selected constraint to a legacy overload. The catalog extraction preserves all
generated Mojo bytes and is covered by generated-source parity checks.

### Shared sequencing policies

`operation_specs.SEQUENCING` describes `flat_tap`, `flat_pair_with`, `followed_by`
and `before` with one callback mode and one retained-output choice. Factory,
pairing and retention decisions are derived from those facts. Selected Pipeline,
legacy Piped and Iter share factory adaptation and generic continuation selection;
Result derives its sequencing callback/output metadata from the same catalog.
Each surface keeps its existing declaration order and documentation wording.

The catalog selects the existing `_IgnoreInput`, `_BorrowedUnary`, `_EffectRetain`
and Result continuations. Family bind still owns branching, repeated invocation,
copy requirements and deferred execution. Result keeps its distinct native-thunk
and owned-library callback boundaries, and lazy iteration keeps its mutable
native callback owner. No shared description transfers those admission rules to
another surface. Generator parity verifies that every Mojo source byte remains
unchanged by this consolidation.

### Structured signature assembly

Native n-ary boundaries choose their fixed carrier parameters before rendering
the declaration. Those ordered operands supply the argument tuple, associated
product types and input constraints together. Library callbacks retain their
variadic carrier pack. Validation constructs its explicit and inferred policy
variants separately, preserving the existing parameter order and inference
separator; it does not rewrite a completed declaration to remove a policy or
specialize a pack.

Borrowing observers similarly choose the native `P: AnyType` callback payload
and the retained `downcast[P, Movable & Deinitable]` carrier payload separately.
The existing native adapter receives the former and the operation receives the
latter. Ordered component lists and the shared native adapter descriptions are
sufficient; this assembly introduces no general source transformation layer.
Generated-source parity preserves every existing Mojo declaration and body.

### Predicate result ABI admission

Selected `ensure`, `recover_if` and `or_else_if` require predicates returning
native Bool. Their inferred result parameter remains part of the public
signature, but Bool's register representation rules out every thin overload
that also requires a non-register result. The shared native ABI generator
accepts optional result-representation evidence; these predicate roles select
the register alternatives while retaining every input convention.

This removes 224 impossible overloads, including intrinsic Result fallbacks,
without changing any retained declaration, parameter position, body, callback
storage or error policy. Native closures and library callbacks retain their
existing admission. Generic thin forwarding still needs the register evidence
required to declare its native function type; equality to Bool alone did not
supply that evidence on the baseline compiler. Maintained generic and rejection
fixtures cover explicit bindings, memory-passed inputs and invalid predicates
returning a memory-passed value.

A small serial cold comparison on Mojo 1.2.0/Linux, with one compiler thread
and two samples per revision, reduced the sampled invalid `ensure` call from
1.54 s to 1.19 s. Complete-workflow samples were too variable to establish a
general compilation speedup. Executable sizes were unchanged. The structural
benefit is removing unreachable candidates; this is not a runtime optimization.

### Recovery signature witnesses

Legacy recovery builds its exact family witnesses before rendering. Error
members and dispatch use `_ErrorFamily[I]`; payload selection and `_Recovered`
retain the original Applicative `I`. That distinction preserves dependent
continuation and error types for conditional families. Shared callback
descriptions supply handler types, arguments and adapters, while recovery keeps
its existing native parameter order and error probes. Owned callable views
share one local specialization across ordinary and conditional recovery.
No completed declaration is rewritten, and generated Mojo remains byte-identical.

### Shared recovery and observation policies

`ErrorOperation` in `scripts/operation_specs.py` owns callback roles and the
value-versus-effect choice for recovery, conditional recovery, error observation,
validation and outcome handling. Generic family emitters use those choices to
select the existing continuations. `ResultOperation.from_error` translates the
same choices into Result-specific carrier constraints. The common two-callback
native-error compatibility rule is shared only where its spelling and meaning
are identical.

`OperationCallback` describes a payload role without choosing its carrier.
Whole-outcome consumers supply that exact carrier spelling explicitly; generic
metadata never constructs a Result type implicitly. Public argument names,
parameter order, signature inference exceptions and receiver admission remain
with each surface. Family construction errors, stored errors and deferred run
errors retain their separate formulas and timing. This consolidation changes
no generated Mojo byte and adds no runtime execution owner.

### Shared effectful reduction policies

`operation_specs.EFFECT_REDUCTIONS` describes effectful folds, predicates and
searches for the selected Pipeline and legacy free/Piped/Iter generators.
Each operation chooses its callback mode, accumulator and stopping policy,
step adapter, initialization and existing reduction driver once. A bound
description supplies the exact result and construction-error expressions.
`EffectChoice` likewise describes the existing `if_effect` continuation,
joined result and branch-error probe. Only literal `Never` is simplified;
generic associated errors retain their original spelling.

The generators still own native admission, receiver constraints, error hints,
family witnesses and source normalization. Borrowing search explicitly passes
the retention alias used by its surface: selected syntax names `_TraverseTap`,
while legacy syntax names `_EffectRetain`. Both keep their existing runtime
owner. The catalog does not change source advancement, branch stopping,
deferred execution or monoid initialization timing. Generated-source parity
covers the selected and legacy effect blocks, and this extraction changes no
production Mojo bytes.

## Native signatures and storage

Native family recognition requires only Functor; Applicative entry points
apply their stronger capability requirement after selection. The default
selection policy remains List, Optional, Result, then Identity (or the legacy
Applicative fallback). Public ArrayFamily, DequeFamily and LinkedListFamily
aliases expose the existing sequence implementations for explicit selection.
Map admission checks the native container shape and Array length before invoking
the shared implementation. `pipeline_values` infers Dict and StringDict
parameters at entry. Their RebindingFunctor.WithElement projection updates the
selected value type after map, filter_map, compact and structural conveniences,
preserving keys and hasher type. This selection uses no private-field reflection.
The only private native collection accesses live in
`fp._internal.native_collections`: Deque settings and StringDict storage
transfer/construction. Algebra and terminal operations use those adapters;
callbacks, accumulation and exception handling retain their existing owners.
The native-boundaries page records the exact source revision, public alternatives
and the ownership/configuration tests needed before replacing a dependency.

Rebinding is an optional capability. A default parameterized family alias on
Functor left nested native callback signatures unfolded on Mojo 1.2, breaking
existing Array map chains. The conditional capability projection retains the
exact original family for ordinary Functors and only expands WithElement when
implemented. MapContract.Family is the public projection for generic fluent
return types; execution remains in the original family primitive.

Capture's existing static factories can also be called through a reusable
`Capture[E]()` value. This gives direct, argument-bound and stateful calls one
consistent entry syntax, without another adapter or additional storage.
The context is stateless and copyable; argument bundles retain their original
consuming receivers, origins and exact native errors.

Partial's finite native prefix signatures, invocation branches and factory
overloads are emitted by `generate_partial.py`. It shares convention spelling
with `native_signatures.py`, while its single copy emitter keeps construction
and repeated calls consistent. Partial retains its native read-pack tail and
copies its bound prefix on each call. Capture's consumed bundles remain a
separate storage owner because replacing Partial's copies with moves would
change repeatability and lifetime semantics. Public Partial parameters and
argument order are unchanged; generated-source parity checks cover all arities.

`generate_context.py`, `generate_capture.py` and
`generate_native_conventions.py` share `scripts/native_signatures.py`.
Known consumed operands use `_NativeOwnedArg`;
read operands and results retain explicit register or memory evidence.
`generate_native_conventions.py` emits thunk, unary, borrowing, binary, keyword
and mutable invocation bodies and `as_unary` pointer admission from the same
descriptor. N-ary calls use the same thin dispatcher, projecting their known
consumed operands so dispatch does not enumerate register combinations as
arity grows. The all-memory signature also serves as the exact symbolic
fallback: a generic forward can preserve the full thin function type while
being unable to prove either concrete register condition. Compare that type
before asking for a closure witness, which a thin pointer does not have.
Literal no-value register callbacks retain their shared specialized boundary.
The single-stage pipe Never helper keeps its weaker Movable bounds, and lazy
callbacks keep mutable access to their owned captures.
Generated files are checked against
their generators by the tooling suite.

The same module owns the mapping from callback shape to library protocol and
native adapter type. Selected Pipeline, Result, Piped, terminal, traversal,
iterator, effect and applicative syntax use that mapping, as does `as_unary`.
The shared module also owns the ordered callback description used by Result,
error, outcome and sequencing generators, so these emitters do not depend on
the Result emitter for signature machinery. Parameter renaming returns an
independently editable description, retaining whole identifiers and their
order. Each admission surface retains its parameter order,
effect selection and ownership constraints. Sharing these facts does not
merge the distinct selected-context and legacy overload policies. The
consolidation produces identical generated Mojo signatures and bodies.

Native closures keep an origin-preserving reference view. Deferred operations
own plain thin pointers through the existing inline optional cell. This avoids
losing native witnesses in generic fields without allocating callable boxes or
copying captures. Capture argument bundles contain native pointers for borrows
and owned fields for consumed operands and keyword dictionaries. Invoking a
bundle consumes its receiver, so native cleanup handles partially moved fields
when the call raises.

The generated `callables._arguments` module owns those layouts, consuming
transitions and invocation for both Capture and every legacy `attempt` shape.
A Capture bundle adds only its selected error context and callback admission;
it moves the whole argument owner into `_BoundThunk` when run. Appending an
argument consumes the storage receiver itself: moving fields out of nested
storage from an outer wrapper is not a valid native cleanup boundary on Mojo
1.2. Keyword packs and owned operands therefore keep one ownership contract
through construction, abandonment, successful invocation and failure.

`data._result` owns Result storage and transformations. `data._attempt` owns
native capture frontends and the single `_attempt_core` catch boundary. Direct
legacy calls and convention adapters now use the same argument bundles,
`_BoundThunk` and `attempt_once` as Capture; they no longer duplicate catches or
build separate pending slots for each owned operand. `attempt_once` retains one
optional pending callable to transfer its consuming receiver through the
borrowed catch context. Public names, parameter order, selectors, exact errors
and the `fp.data` / `fp.data.result` import paths remain unchanged. This changes
execution ownership after admission; it does not repair invalid legacy
overloads that crash while the compiler is still choosing a signature.

Literal no-value returns and `raises Never` have explicit invocation paths.
Capture also needs a literal Never admission specialization to resolve the
read/read tie with a selected-error closure signature. Stateful factories and
`as_unary` share a borrowed-pointer fallback for symbolic signatures, while
exact register variants take priority for concrete functions. Both owners copy
the pointer into their own cell; reassigning the caller's pointer cannot change
it. This admission policy applies only to thin pointers, never to closures.

Conditional, Result and selected APIs use the same thunk, unary and borrowed
callback views. Each view calls its canonical native helper directly. Views
have no function-valued invocation policy or callback-name specialization.
Zero-argument Result continuations compose the existing `_NativeThunkRef` and
`_IgnoreInput`; retention and consumption remain in their existing owners.

The direct call boundary is significant on Mojo 1.2: forwarding a Bool through
the older function-valued policy and then the shared native helper can corrupt
the result at O0. Removing that policy fixes the observed branch-selection
failure without requiring callers to annotate or inline their predicates.
The native-view regression tests check declarations and borrowed closures at
O0/O3 through source and precompiled imports.

Native Capture admission inlines internally to retain closure storage across
generic forwards at O0. This does not repair Mojo's independent optimizer issue
with arbitrary callbacks that mutate owned captures. Those callbacks retain
the documented `@always_inline` requirement or use explicit mutable state.

## Current limits

- Capture binds at most two positional operands and one homogeneous keyword
  pack. Fixed named arguments, omitted defaults and larger packs use a native
  zero-argument closure or an existing consuming callable.
- A stored keyword pointer must name its pack `kwargs` in its explicit native
  type. Mojo 1.2 cannot convert stored pointers between pack names, even without
  this library. Direct callback declarations retain their own spelling.
- Legacy invalid native overloads can still require explicit callback-type
  bindings for normal diagnostics. Selected Pipeline and Capture fixtures use
  ordinary calls; no compiler crash or timeout counts as successful rejection.
  The [API-quality audit](native-boundaries.md#current-api-quality-audit) reproduced
  the generic-error inference failure without this library. Selecting the error
  before matching the callback remains the architectural boundary; merging the
  pure and raising legacy overloads or adding a fallback did not repair it.
- Native Array iterator transfer needs the existing local drain into owned
  List storage before escape. Its O(N) buffering is part of the documented
  source normalization cost.
- Linux x86-64 qualification does not establish macOS or GPU behavior. The
  published 1.0.0 package targets Mojo 1.1; Mojo 1.2 uses the nightly checkout.

The [native boundaries](native-boundaries.md), [compatibility inventory](../guides/compatibility.md)
and [performance observations](performance.md#mojo-12-capture-qualification)
give the detailed scope and evidence.

### Generic recovery metadata

`RecoverContract` names value-returning recovery's admission, output family,
carrier and native construction error. A generic client no longer imports
the private `_Recovered` adapter to spell `Handled` and `HandleError` in its
signature. The descriptor lives beside that adapter in `algebra.errors`;
primitive operation contracts do not acquire a dependency on derived recovery
and traversal modules. It adds no invocation or storage layer.

Its `Compatible` predicate now combines input/output/carrier checks with
`ReceiverCompatible` and `OperationCompatible`. The latter forwards the family's
declared adapted-handler admission, guarded by the earlier checks. Combined
wrappers inherit the stronger predicate; wrappers spelling individual predicates
add the receiver and operation witnesses. Legacy Piped's signature checks retain
their existing shape. Deferred ResultT/Reader recovery still retains native
handler errors until run.
Conditionally error-capable Applicatives use the same public downcast witness
in the contract and operation, preserving dependent error-type identity.

The recovery-contract client covers immediate success skipping, branching,
deferred timing and errors, a custom family's construction error, owned
one-shot handler cleanup and borrowed origins. Ordinary invalid input, output,
carrier and cross-origin calls remain separate rejection fixtures.

### Selected family recovery

Selected `recover` and `or_else` honor `ApplicativeError`, including deferred
transformers and custom families backed by native Result storage. Value
recovery delegates through the existing `_Recovered` adapter and family
primitive. Canonical Result recovery and intrinsic Result calls under
non-error families retain their existing behavior. Here a non-error family
means one with neither `ApplicativeError` nor `ErrorMapping`; native Result
storage does not grant a mapping-only family recovery.

`functions._recovery` owns the selected `or_else` distinction: canonical Result
and legacy non-error-family Result calls may change the stored-error type;
other error-capable families preserve their selected layer. One compile-time
policy supplies callback input, admission, output family, carrier and native
construction error. Its execution methods only delegate to the existing
Result or family primitive. There is no duplicated catching, storage or
ownership implementation.

Public `fp.functions.OrElseContract` exposes that selected contract to generic
clients. It belongs to the syntax layer because the type-changing Result case
is broader than the `ApplicativeError` primitive's contract. Choosing the
policy before native callback admission avoids asking overload resolution to
prove whether two still-generic stored-error types are equal or different.
Library handlers use one selected entry. Native admission separates
`ApplicativeError` families from intrinsic Result calls under families with
neither error capability. Mojo cannot use a generic non-error-family proof to
resolve the policy's projected callback input. The intrinsic Result boundary
spells that known input directly; its generic wrappers forward both negative
capability proofs. Both admissions use the same execution policy.

Previously, Result storage could bypass an explicitly selected error family's
recovery implementation. Honoring that family intentionally corrects this
behavior. A generic wrapper over an entirely unknown family must project
`OrElseContract.Family`, `Out` and `Error` instead of promising that every family
returns the handler's native Result and raises only the handler's error.
Ordinary canonical Result calls keep their existing type-changing behavior.

The same boundary applies to conditional recovery, error observation, success
validation, outcome handling and whole-outcome observation. A mapping-only
family keeps `map`, `map_err` and `map_both`; the later
[mapping observation pass](#observation-through-error-mapping) also admits plain
`tap_err` through its own mapping policy. The other operations require
`ApplicativeError` and, where documented, Monad. This corrects the previous
fallback that could silently discard a mapping-only family's policy by
reselecting Result. `.get()` followed by `pipeline(...)`, or explicit
`pipeline[ResultFamily[E]](value)`, makes that policy choice deliberate for a
native Result carrier. Public contract-based wrappers still forward
`Compatible`; no additional negative proof is needed at that boundary.

Maintained `context_error_capability_*` fixtures cover twenty ordinary native
and library rejections across the ten affected methods. The positive client
checks unsupported `OrElseContract`, `RedeemContract` and `RedeemWithContract`
metadata, mapping continuation, and the same callback shapes under canonical
Result, explicit reselection and Identity's intrinsic fallback. No invalid
call relies on explicit callback type bindings.

### Selected error observation

Selected `tap_err` and `flat_tap_err` delegate to `_ObserveError` and the
selected family's recovery primitive. The existing `_ObserveFailure` finisher
owns effectful observation: Result replaces a failure with the observer's
failure, Validation accumulates observer-before-original, and empty observer
effects remain empty. Plain observation discards its callback output and
reintroduces the original error using the family's failure constructor.

`TapErrContract` and `FlatTapErrContract` expose the existing admission and
result/error projections through one private metadata owner in `algebra.errors`.
They add no invocation or storage layer. Source and callback origins, custom
construction errors, deferred execution and receiver/copy requirements remain
with their existing owners. Error-capable families control observation even
when their native storage is Result. Intrinsic Result overloads remain for
non-error families, with disjoint capability guards preserving generic native
forwarding. No caller chooses an overload based on error-type equality.

### Selected conditional recovery

Selected `recover_if` and `or_else_if` reuse `_ConditionalRecovery` through the
selected family's recovery primitive. The predicate borrows the stored error;
a match consumes it through the handler, and a nonmatch reconstructs failure
through that family. `_Recovered` owns value lifting for `recover_if`. This
requires `ApplicativeError`, so Validation participates without a Monad.
Success skips both callbacks; deferred families retain deferred execution.

`RecoverIfContract` and `OrElseIfContract` publish admission and exact
family/output/construction-error projections. The value contract shares the
effect contract's predicate and callback-error metadata, while checking the
unlifted value boundary directly. Selected admission also forwards the family's
adapted-handler predicate; generic wrappers use the combined contract or its
public components. Callback and failure-constructor errors are compared through
total exact-type equalities, preserving symbolic native-error inference.
Intrinsic native Result overloads remain disjoint under non-error families.
Canonical Result and custom families with Result storage use family recovery;
no extra selector, callback binding or invocation mechanism is introduced.

### Selected success validation

Selected `ensure` delegates to `_Ensure` through the family's existing bind
primitive. The predicate borrows successes and a rejection invokes the
borrowing error factory; existing failures skip both callbacks. The selected
family owns failure construction, branch behavior, receiver checks and exact
construction/deferred errors. Custom families retain these policies even when
their carrier is native Result. Canonical Result uses the same family path;
intrinsic Result calls under proven non-error families remain disjoint.
An error-capable family without Monad, including Validation, cannot bypass the
bind requirement by exposing Result storage.

`EnsureContract`, declared beside `_Ensure` and exported by `fp.algebra`, names
the selected admission predicates and family/output/error projections. Its
`Compatible` includes `I.BindCompatible[V, Continuation]`; this is the selected
entry contract, while legacy Piped's signature predicates remain unchanged.
Expanded generic proofs must include bind admission. No validation execution
or callback storage is duplicated. The selected generator shares callback
parameter grouping across validation, conditional recovery and intrinsic Result
operations, preserving inferred parameter order and the inference barrier.

### Selected outcome handling

Selected `redeem` and `redeem_with` share recovery's canonical-Result versus
custom-family selection. Intrinsic policies delegate to the existing Result
methods; family policies delegate to `_Redeem`. `_Materialize` exposes only
the original selected outcome before `_OutcomeFold` invokes one handler.
This prevents a returned failure or native raise from entering the other arm.
There is no new dispatcher, storage owner or exception interpreter.

Public `fp.functions.RedeemContract` and `RedeemWithContract` aliases share
one private metadata descriptor. They project policy admission, output family,
carrier and construction error for generic wrappers. `OperationCompatible`
checks materialization map/recovery and the final map or bind admission.
Carrier agreement alone does not authorize a custom family operation: its
primitives may assume the caller already enforced these predicates. Intrinsic
Result uses its own admission; receiver, copying and native-error checks stay
with the existing execution owners. Value handling uses
`_MappedFamily` for payload-dependent selections; effect handling keeps the
family's stored-error layer. Canonical Result retains its type-changing
`redeem_with` behavior. Native admission under error-capable families and
intrinsic Result admission under non-error families remain disjoint; library
handlers use one contract route. Exact Result membership shares the existing
recovery metadata predicate, and callback parameter grouping shares the
selected generator's existing helper.

Family value handling requires ApplicativeError; effect handling additionally
requires Monad. Validation supports the former without acquiring the latter.
Custom family construction errors, deferred run errors, origins, one-shot
cleanup and branching repeatability remain with their existing owners.

### Selected whole-outcome observation

Selected `attempt_tap` delegates to the existing `_AttemptTap` plan:
`_Materialize` exposes the selected native Result, `_EffectRetain` observes
and retains it, and `_Restore` reconstructs the original through the family.
Successful observer branches restore the outcome; observer failures replace
it and empty effects remain empty. Outer stored-error layers remain outside
the selected observation. Custom families own both construction and restore,
including when their storage is native Result.

`AttemptTapContract` is declared beside that plan and exported by `fp.algebra`.
It exposes source/observer/input admission and the exact map, recovery and
bind predicates consumed by the plan. The selected signature adds these
family proofs without moving receiver, copying, join or error compatibility
checks out of their existing bodies. Both combined and component predicates
forward generically. Output and construction-error projections refer directly
to the plan; no execution or callback storage is added. Family admission
requires ApplicativeError and Monad; intrinsic Result overloads remain only
under non-error families, preserving native generic forwarding.

### Compilation cost after selected outcome support

A bounded comparison of `e42c2df` with `cda1207` includes predicate pruning,
selected outcome handling and whole-outcome observation. Four unchanged clients
were compiled serially at O3 on Mojo 1.2.0/Linux with two compiler threads and
an empty cache for every build. Baseline/current/current/baseline ordering gives
two samples per variant, 16 checked compilations in total. Median seconds were:

| Client | Before | After |
|---|---:|---:|
| `docs/examples/selected_pipeline.mojo` | 11.15 | 9.90 |
| `tests/runtime/test_context_result_redeem_with.mojo` | 5.58 | 7.03 |
| `tests/runtime/test_context_result_attempt_tap.mojo` | 4.51 | 4.95 |
| `tests/compile_fail/context_reject_result_ensure_input.mojo` | 1.44 | 1.09 |

The selected-pipeline and rejection clients improved, while the two Result
outcome clients became slower. Their exact family contracts introduce additional
compile-time work; the combined changes are not a general compilation speedup.
Executable sizes were unchanged for all three successful clients. These small
samples are a baseline for further admission work, not a broad performance
claim or a substitute for semantic qualification.

The stored-error mapping core was compared separately with `fc9b645`, using
four unchanged clients and the same serial O3, two-thread, empty-cache,
baseline/current/current/baseline method (16 checked compilations):

| Client | Before | Mapping core |
|---|---:|---:|
| `docs/examples/selected_pipeline.mojo` | 10.50 s | 10.53 s |
| `tests/runtime/test_context_result_map_both.mojo` | 5.64 s | 6.89 s |
| `tests/runtime/test_context_result_map_err.mojo` | 4.40 s | 4.54 s |
| `tests/compile_fail/context_reject_result_map_both_input.mojo` | 0.58 s | 0.96 s |

Executable sizes were unchanged. The richer mapping admission costs more in
these `map_both` probes; the broader selected-pipeline sample is effectively
unchanged. Two samples per variant do not establish general build performance.
Core semantic qualification passed 76 source/package O0/O3 checks, 37 existing
rejection regressions, seven regression/example programs, tooling and strict
documentation checks.

### Generic sequencing metadata

The four public sequencing contracts name the existing selected Monad
operations: `FlatTapContract`, `FlatPairWithContract`, `BeforeContract` and
`FollowedByContract`. A private descriptor in `algebra.sequencing` owns their
shared admission and result/error projections. Public aliases select the
existing retention or borrowed continuation and factory input adapter, without
exposing boolean mode parameters or adding execution. The module depends on
the existing continuations; primitive operation contracts gain no dependency
on derived sequencing.

`Compatible` describes selected entry admission: exact borrowed input,
produced-carrier membership and family bind admission. Component predicates
remain separate so legacy Piped's input-and-carrier signature stays unchanged.
Bodies retain their existing receiver and retained-value copy checks.
Both combined and pre-existing expanded proofs forward through the public
aliases. Metadata projects the exact family witness, output carrier and
construction error; family-specific deferred run errors are never collapsed
into callback errors at construction. Conditional Applicative-to-Monad clients
use the same public `downcast[I, Monad]` witness in the contract and pipeline
selection for all four operations.

The generic clients cover all four operations, selected fluent continuation,
legacy admission, a custom family construction failure, deferred Reader timing,
mutable branching callbacks, one-shot move-only cleanup, and borrowed origins.
Ordinary rejection clients cover callback/input/source/carrier mistakes, exact
native errors, cross-owner origins, one-shot callbacks on branching sources,
and retained move-only payloads in branching effects.

## Further migration

Every legacy Piped method now has a selected counterpart in the inventory.
Equal method names do not imply equal capability coverage: stored-error mapping
supports Result, Validation and all five transformer families, plus custom
ErrorMapping dictionaries. ResultT uses its base map; the other transformers
require a base Monad with ErrorMapping. Extension contracts still matter for
custom dictionaries and deferred families.

Future work should start with executable user examples and evaluate annotation
burden, diagnostics, ownership, and cold compilation cost. Keep legacy bindings
until replacements meet those contracts. Do not broaden an operation by
recognizing native storage and discarding the selected family's semantics.

### API quality and architectural consolidation

The current priority is improving existing APIs before adding capabilities.
Judge each change using executable client code, including generic clients,
and measure both the caller's requirements and the number of handwritten
implementations of a contract. Generated signature counts alone are not a
measure of architectural duplication: Mojo still needs distinct native ABI
evidence at admission.

1. **Consistent callback use.** A declaration, stored pointer and library adapter
   should work interchangeably wherever their receiver and argument contracts
   agree. The first correction is stored-pointer admission in `as_unary`, with
   shared ABI rules and unchanged ownership, errors and copyability. Keep
   ordinary invalid calls in the source/package O0/O3 boundary matrix.
2. **One invocation owner.** Remove private callback-name distinctions when
   Mojo 1.2 no longer needs them. First delegate old paths to existing owners,
   then simplify the views and their generator consumers. Preserve generic
   forwards, no-value callbacks and borrowed origins throughout.
3. **Shared signature descriptions.** Consolidate repeated callback descriptions
   in syntax generators around the existing native-signature owner. Keep
   family selection, admission and runtime execution separate. Require
   unchanged generated public signatures for mechanical refactors.
4. **Simpler generic extension.** Use real mapping, traversal and deferred-family
   wrappers to identify repeated proof obligations. Reduce caller annotations
   only when the shared operation contract preserves custom family semantics
   and exact dependent errors and origins. Avoid a new public wrapper merely
   to hide the same constraints elsewhere.

Qualify and commit each complete pass separately. No CI work is part of this
sequence. Resource scopes and fallible source advancement remain later design
work, after these improvements to the existing API.

Stored-error mapping is qualified for Result, Validation, custom dictionaries
and all five transformers. Maintained source/package O0/O3 checks cover normal
and invalid calls, including the boundary between mapping and recovery.
Resource scopes and source advancement remain later design work.

### Proposed stored-error rebinding

**Core and all five transformers implemented.** `ErrorMapping`,
`MapBothContract` and `MapErrContract` support selected `map_err` and `map_both`
for ResultFamily, ValidationFamily, ResultT, OptionalT, ReaderT, StateT, WriterT
and custom dictionaries. One two-arm primitive owns mapping. Ordinary Result
calls infer their destination;
Validation requires an explicit target when the stored-error type changes.
Existing positional callback bindings retain their meaning. The target is a
trailing defaulted binding, conventionally supplied as `Target=...`.

A dictionary explicitly declares `DefaultErrorTarget[A,E]`; fixed policies
use `Self`. Mojo 1.2 evaluates an inherited generic alias default of `Self`
correctly in body assertions but keeps it opaque during ordinary overload
selection. Requiring the policy declaration makes the destination visible
without adding normalization machinery or caller annotations. Result supplies
its deterministic new-error target; Validation supplies itself. The schematic
protocol below reflects this qualified change from the initial design.

Selected custom families own mapping even when their storage is native
Result. A family with ApplicativeError but without ErrorMapping rejects these
operations normally. Conversely, a mapping-only family cannot borrow
recovery or other error operations from Result storage. The intrinsic Result
fallback consistently requires neither capability; generic intrinsic wrappers
must forward both negative capability proofs.
`ApplicativeError` cannot supply error rebinding: its failure and recovery
primitives intentionally preserve one selected error type.
`RebindingFunctor.WithElement` changes selection metadata, not a carrier or
error channel. Changing an alias alone would mislabel the original carrier.

<!-- example: docs/examples/selected_error_mapping.mojo -->

#### One execution primitive

The primitive maps both success and selected failure in one traversal.
`map_err(g)` derives from it using the existing consuming `Identity` callback
on success. `map_both(f, g)` must not generally expand to `map(f).map_err(g)`
or the reverse. For `ResultT[ListFamily, E]` containing
`[Err(e1), Ok(a2), Err(e3)]`, one traversal observes callbacks in the order
`g(e1), f(a2), g(e3)`. Two traversals group callbacks by branch. That changes
observable mutation, which native exception stops evaluation, and when later
callbacks run. Composition can also introduce an additional custom-family
construction failure and another deferred stage.

The new primitive is an algebraic boundary, not another Result dispatcher.
`ResultFamily` delegates to existing `Result.map_both`, whose owned fold
already owns branch selection, payload movement and unused callback cleanup.
ResultT delegates one base map to that Result owner; OptionalT delegates to
the base family's primitive with the existing Optional success-map adapter.
Reader, State and Writer share `_BimapOp`, which reaches the same checked base
primitive through their existing transport. Existing `Functor.map` remains its
own operation; adopting this capability does not replace all mapping with
two-arm machinery.

`ErrorMapping` extends `Functor` independently of `ApplicativeError`.
Mapping a stored error does not require failure construction or recovery.
For example, State recovery currently requires copyable state because it
restarts a handler with saved input state. Mapping the error after one State
run requires no rollback and should not acquire that copying requirement.
Validation remains eligible without acquiring Monad.

#### Capability and exact admission

The implemented core protocol is summarized below in schematic notation.
`Value` means `Movable & Deinitable`; `Callback` means
`UnaryContract & Movable & Deinitable`. These abbreviations keep the summary
readable; the source declarations are the compiler-qualified interface.

```text
trait ErrorMapping(Functor):
    Failure: Value
    ErrorCarrierCompatible[V: Value]: Bool

    DefaultErrorTarget[NewValue: Value, NewFailure: Value]: ErrorMapping

    BimapCompatible[Target: ErrorMapping, V: Value,
                    F: Callback, G: Callback]: Bool
    Bimapped[Target: ErrorMapping, V: Value,
             F: Callback, G: Callback]: Value
    BimapError[Target: ErrorMapping, V: Value,
               F: Callback, G: Callback]: Value

    static bimap[Target: ErrorMapping, V: Value, F: Callback, G: Callback](
        var on_success: F, var on_failure: G, var source: V
    ) raises Self.BimapError[Target, V, F, G]
        -> Self.Bimapped[Target, V, F, G]
```

`Failure` names exactly one selected stored-error channel, including its
origins. A family implementing both capabilities must give `ErrorMapping`
and `ApplicativeError` the same selected `Failure`. Its carrier predicate
should share the existing error-carrier validator where applicable, rather
than add a second definition of membership. It also validates mapping-only
families for which recovery is unavailable.

An admitted target must implement `ErrorMapping`. Core contracts and dictionary
primitives retain that bound so a generic client can name the selected failure
and establish that the output belongs to the new error channel. The selected
`Pipeline` boundary accepts `Target: Functor` and requires
`conforms_to(Target, ErrorMapping)` before forwarding its exact public downcast.
This supports ordinary `Target=OptionalT[...]` calls: the alias preserves its
Identity specialization and common Monad bound, while its selected family
supplies the conditional mapping capability. This avoids introducing a
separate public channel-descriptor capability. Implementers consequently
promise a coherent mapping interface on the destination, although any
particular next operation can still be rejected by its admission predicates.

`DefaultErrorTarget` is a required candidate projection, not an unconditional
conversion. Fixed-policy dictionaries declare `Self`; exact target checks
reject a changed error when no destination policy has been specified.
Deterministic families declare their new destination. A family whose selection depends on the success type must also
reselect that metadata, reusing `RebindingFunctor.WithElement` when available
and proving that the selected result implements `ErrorMapping`. The existing
`WithElement: Functor` bound alone does not prove this. No unsupported-target
sentinel, erased `AnyType` family, or automatic Result fallback is needed.

`BimapCompatible` belongs to the source family. It admits only supported
source-to-target policy transitions and includes operation-specific native
error, receiver, repetition and representation requirements. Equal payload
and failure types alone do not authorize replacing a custom dictionary with
an unrelated one. Families may add construction or execution errors, but
must expose their exact types. Neither callback's native exception becomes a
stored failure.

Public metadata keeps private execution adapters out of generic clients.
`MapBothContract` has these parameters, projections and component predicates
(the source additionally guards rejected output projections):

```text
MapBothContract[
    I: ErrorMapping, V: Value, F: Callback, G: Callback,
    Target: ErrorMapping = I.DefaultErrorTarget[F.Out, G.Out]
]:
    SourceFailure = I.Failure
    Failure = G.Out
    Family = Target
    Out = I.Bimapped[Target, V, F, G]
    Error = I.BimapError[Target, V, F, G]

    SourceCompatible = I.ErrorCarrierCompatible[V]
    InputCompatible = F.Arg == I.Element[V] and G.Arg == I.Failure
    TargetCompatible = Target.Failure == G.Out
    OutputCompatible = (Target.ErrorCarrierCompatible[Out]
                        and Target.Element[Out] == F.Out)
    OperationCompatible = I.BimapCompatible[Target, V, F, G]
    Compatible = (SourceCompatible and InputCompatible and TargetCompatible
                  and OutputCompatible and OperationCompatible)

MapErrContract[
    I: ErrorMapping, V: Value, G: Callback,
    Target: ErrorMapping = I.DefaultErrorTarget[I.Element[V], G.Out]
] = MapBothContract[I, V, Identity[I.Element[V]], G, Target]
```

All type equalities above include embedded origins. Both callback inputs
must be checked at admission, and both output types retain their origins in
the exact destination carrier. Source, target and callback witnesses must be
identical between the contract and operation; a generic conditional downcast
must not be replaced by a superficially equivalent family expression.

A checked operation requires `Contract.Compatible`, consumes the callbacks
and source once, and delegates directly to `I.bimap`. Dictionary primitives
retain the existing assumption of admitted types and validate their concrete
receiver/ownership requirements. A generic wrapper forwards either
`Compatible` or **all five** component predicates; the previous intrinsic
Result input predicates alone do not establish this new family contract.
The native boundary additionally keeps the existing selected native-error
admission. Maintained generic clients qualify combined and component forwarding in
both directions; boolean spelling alone is not a compiler proof.
Result's native-error compatibility uses eager Boolean `|` for total type
equalities. Short-circuit `or` hides symbolic equal-error and pure/error
proofs from Mojo 1.2 overload selection. Policy downcasts and potentially
invalid projections retain their conditional guards.

Input and target admission must not require constructing an invalid output
alias merely to report an error. Projection order and safe rejected
candidates are explicit prototype gates. Compiler crashes, origin erasure,
or a requirement to spell ordinary callback types would fail the design's
usability goal, not qualify as acceptable rejections.

#### Family-specific destinations and owners

The implemented families use these destination policies and existing execution
owners. OptionalT, ReaderT, StateT and WriterT require ErrorMapping only from
their base Monad; that base need not support ApplicativeError.

| Source family | Recommended destination policy | Execution owner |
|---|---|---|
| `ResultFamily[E]` | Infer `ResultFamily[NewE]`. | Existing `Result.map_both` and owned Result fold. |
| `ValidationFamily[S]` | Keep `S` for the same error type. A changed error requires explicit `ValidationFamily[S2]`, where `S2.Value == NewE`. | Existing Result fold; the destination dictionary governs subsequent accumulation. |
| `ResultT[M, E]` | Change the inner selected `E`; retain the base policy, reselecting its payload metadata only when necessary. | One base `M.map` over an adapter to the existing Result two-arm owner. |
| `OptionalT[M]` | Rebind the selected base error through `M`; retain the Optional layer. | Base two-arm owner, with the existing Optional success-map adapter. |
| `ReaderT[M, R]` | Rebind `M`; retain exactly `R`. | Existing Reader run/hoist transport, then the base two-arm owner. |
| `StateT[M, S]` | Rebind `M`; retain exactly `S`, without requiring `S: Copyable` for mapping. | Existing State run/hoist transport and success-pair adapter. |
| `WriterT[M, W]` | Rebind `M`; retain exactly the log monoid `W`. | Existing Writer unwrap/hoist transport and success-value adapter. |
| Custom family | Default to itself; override deterministic rebinding or require an explicit admitted target. | Its declared primitive, delegating shared representation semantics where appropriate. |

The destination of a transformer must still satisfy its base requirements.
ReaderT, StateT, WriterT, OptionalT and ResultT require a Monad base; native
Result representation does not make a Validation base a Monad. An explicit
target cannot silently change the environment, state type, log policy,
outer error channel or transformer order.

Admission checks the raw proposed base before wrapping it. OptionalT, ReaderT,
StateT and WriterT leave a non-Monad default candidate unwrapped, allowing
ordinary policy rejection. An explicit permitted Monad base can still be
selected independently of that default. A downcast never supplies missing
Monad evidence. ResultT retains a
well-formed candidate using its original base when payload rebinding proposes
a non-Monad, but `OperationCompatible` rejects that operation even when the
stored-error type is unchanged. This candidate keeps metadata valid and never
executes as a fallback policy.

Validation maps its already accumulated error value once. It does not split
that value, call the destination Semigroup's combine operation, or infer a
Semigroup from its element type. Two Semigroups can operate on the same
native type with different policies. The recommendation permits an explicit
same-type transition from `S` to `S2`, making the change of future policy
deliberate. Arbitrary error mapping is not promised to preserve Applicative
combination laws: such a stronger claim would require the mapping to respect
the two Semigroup operations.

For nested `ResultT[ResultFamily[OuterE], InnerE]`, the carrier is
`Result[Result[A, InnerE], OuterE]`. Selected error mapping changes only
`InnerE`. An outer stored failure skips both callbacks; a native raise at
either level remains native. The inner operation must work without requiring
the base to implement `ErrorMapping`: it only needs the base's existing map.
Rebinding payload metadata in `M` is not permission to change `OuterE`.
Mapping that outer channel requires explicitly selecting that layer; the
library must never search a stack for a matching error type.

#### Construction, execution and ownership

`BimapError` and `Contract.Error` describe construction only. The exact output
carrier retains its existing execution contract. A universal `RunError`
projection would misrepresent eager values and Reader's origin-indexed
execution. Generic runners continue to use the appropriate public Reader,
State or Writer execution metadata.

For a Reader source action `S`, base family `M`, admitted destination base
`N`, and callbacks `F` and `G`, the projections at run origin `o` are:

```text
OutputAction.Family = ReaderT[N, S.Env]
OutputAction.Out[o] = M.Bimapped[N, S.Out[o], F, G]
OutputAction.Error[o] = CommonError[
    S.Error[o], M.BimapError[N, S.Out[o], F, G]
]
```

Here `CommonError` denotes the existing Never-or-exact-same-error rule, not
a new union type. Admission rejects incompatible inhabited native errors at
the boundary where they must share a raise type. Construction may still
raise a different error from deferred execution; it must not collapse those
two stages into one callback error. Reader admission and running retain the
actual origin checks in addition to the existing witness-origin checks.

State mapping uses the corresponding non-origin-indexed equation with the
existing `_MapFirst` success adapter `(A, S) -> (B, S)`. It runs the source once
and transforms the returned base carrier. It does not save, restore or copy
the incoming state, including when the source fails. This permits mapping with
move-only state without promising State recovery. Writer mapping uses its
existing `_MapValue` adapter `(Log, A) -> (Log, B)` and constructs a real
destination `WriterValue` around the transformed base carrier. It neither
copies nor recombines the log just
to change an error. Deferred base actions remain deferred when unwrapped.

The shared `_BimapOp` in `effects._transport` wraps the base's
`MapBothContract` and checked runner. Existing Reader and State hoists now
accept an admitted destination family; their source fields and run bodies
retain the original action and dictionary. Reader's actual-origin checks keep
both environment-retaining outputs and native errors intact. Writer's existing
transport constructs the destination wrapper around the transformed base.

The original three-parameter `_Hoisted` and `_hoist` bindings delegate with
the source family, retaining local/listen/censor behavior. The new destination
parameter changes output metadata without relabeling or casting the source
action. Reader and State construction raises Never; Writer preserves the base
operation's exact construction error. Deferred base execution stays deferred.
This generalizes existing transport without adding an interpreter or runner.

Where native Result construction can raise only callback errors, the exact
error is the existing common error of the two callbacks. Custom families
declare their own construction costs. ResultT's construction error is its
base `MapError` for the two-arm inner adapter; a deferred base moves that
work into its existing execution type. OptionalT and the other transformers
delegate to the base's corresponding projections rather than assuming
Result's error formula.

One-shot carriers may consume one-shot callbacks. Branching carriers retain
their existing repeatability and copy requirements; no universal `Copyable`
bound belongs on this capability. Each original success invokes only its
success arm, and each selected failure only its failure arm. Empty outer
effects invoke neither. A stored error is consumed once, and callback
outputs are not fed back through either arm. Discarding an unopened action
invokes neither arm and destroys retained owners once.

No implementation may use old-family `_Joined` to combine an original
success carrier with a new-error failure carrier. Both branches must first
produce the admitted destination representation, and any necessary join
belongs to that destination. The existing Result fold or base map usually
avoids such a join entirely. Deferred branch joins must preserve the new
family, environment/state witnesses and origin-indexed outputs.

#### User calls and generic clients

The Result, Validation and transformer call shapes are illustrated by the
examples above and below:

```text
pipeline(result).map_err(to_message)
pipeline(result).map_both(format_value, to_message)
pipeline[ReaderT[ResultFamily[ParseError], Config]](action).map_err(to_message)

pipeline[ValidationFamily[ParseErrors]](validation)
    .map_err[Target=ValidationFamily[DisplayErrors]](format_errors)
```

Result and the transformers infer their declared default destinations.
Validation supplies the policy that the error value's type cannot determine. `Target` is a trailing
defaulted binding, supplied by name in examples; existing positional callback
and native-error bindings keep their meaning.

A generic selected wrapper should name
`C = MapBothContract[I, V, F, G, Target]`, require `C.Compatible`, and return
`Pipeline[C.Family, C.Out, NativeContext]` while raising `C.Error`. It can
continue fluently in the declared destination without importing private
ResultT, Reader or State adapters. It cannot promise `Pipeline[I, ...]`
unless it proves the target equals `I`. For `map_err`, `MapErrContract`
also removes the need to spell the success Identity adapter.

For conditional aliases, a generic wrapper accepts `I: Functor` and
`Target: Functor`, requires both complete selected families to conform to
`ErrorMapping`, and forms the contract with `downcast[I, ErrorMapping]` and
`downcast[Target, ErrorMapping]`. Use those same witnesses for all projections
and forward `Compatible` or all five components. A proof about a transformer's
base alone does not establish the public alias's capability; no
`M != IdentityFamily` premise or private adapter proof is needed. Ordinary
calls still pass the source and target aliases directly. Existing wrappers
bounded by `ErrorMapping` continue to accept statically capable dictionaries.

<!-- example: docs/examples/selected_layer_error_mapping.mojo -->

<!-- example: docs/examples/selected_transport_error_mapping.mojo -->

Native overloads retain the existing signature owner and selected error
context. They fix source payload/error inputs before inferring callbacks,
then compute the destination from callback outputs. A native context is
still an admission rule for native callbacks; it does not replace library
callables' errors or erase family construction errors. The implementation
must qualify generic outputs and errors, pure/raising mixtures, declarations,
stored pointers and adapters without extra caller type hints.

#### Unsupported cases and compatibility decisions

- A custom error-capable family without `ErrorMapping` cannot borrow this
  operation merely because its storage happens to be Result. The proposed
  correction is a normal unsupported-capability diagnostic. That family can
  adopt the capability without changing native storage.
- Intrinsic Result calls under a proven non-error family retain their
  existing type-changing behavior. The fallback guard must exclude both
  `ApplicativeError` and `ErrorMapping`; a mapping-only family also owns its
  semantics. Canonical Result adopts the capability directly. Existing
  Result methods and legacy Piped bindings need no migration in this pass.
- A changed Validation error without a supplied destination Semigroup is
  rejected. No fallback selects Result or a convenient default accumulation
  policy. An explicitly unrelated target is also rejected even if its
  carrier happens to have the correct types.
- A callback cannot change an unselected stored-error channel, convert a
  native raise into storage, change auxiliary state/log types, or escape
  another owner's origin. Incompatible inhabited native errors require an
  explicit user mapping, as elsewhere in the library.

The core implementation rejects selected custom-family calls that previously
discarded their policy. Such dictionaries adopt ErrorMapping explicitly.
A same-error Validation policy transition also requires an explicit target.
These compatibility decisions are documented with the selected API. All five
transformers preserve the selected layer and its auxiliary types; explicit
base-policy changes remain subject to the source family's contract.

#### Adoption sequence and acceptance gates

1. **Complete:** define one capability, two-arm semantics, exact target
   admission and the compatibility decisions above.
2. **Complete:** qualify the Result/custom-family/Validation core. Maintained
   fixtures cover ordinary invalid carriers, target policies and projections,
   origins, receivers and errors; combined/component generic proofs;
   conditional witnesses; positional bindings; default destinations; and
   one-shot cleanup. Canonical and proven intrinsic Result generic forwarding
   remain supported. Required explicit default-policy declarations replace
   the compiler-opaque inherited default.
3. **Complete:** ResultT and OptionalT delegate through existing inner
   adapters and base owners. Maintained clients cover interleaved branch order,
   outer failure/absence skipping, exact additional base errors, nested selected
   channels, branching callback state, ownership, rebinding bases and invalid
   non-Monad defaults. Conditional source/target witnesses keep ordinary alias
   calls free of casts and preserve positional bindings.
4. **Complete:** Reader/State/Writer reuse their existing transport with
   an admitted destination and one shared base operation. Acceptance gates
   cover custom construction versus execution errors, actual borrowed run
   origins, move-only state/log cleanup and unopened-action disposal. Mapping
   adds no rollback or copying requirement. Existing local/listen/censor
   consumers retain their entry points and remain regression gates.
5. **Complete for these families:** maintained generic/user examples and
   documented family obligations accompany each extension. Source/package
   O0/O3 matrices and bounded cold comparisons are recorded below; complete
   passes are published separately. No CI or compiler work is part of this
   sequence.

#### ResultT and OptionalT qualification

On Linux with Mojo 1.2.0 (`2016d0cd`), the layer and existing core matrices
passed all 152 source/package O0/O3 checks. Thirteen packaged regression and
example programs, 22 existing Pipeline mapping rejections, 46 tooling tests
and strict documentation checks also passed. Reports retained unchanged
source/package inputs and zero audit failures. The example inventory now
contains 76 programs; the public inventory remains 318 exports.

A bounded cold comparison against `461f907` used the same four existing
clients, O3, two compiler threads, isolated empty caches and two samples per
revision in alternating order. All 16 observations passed; executable sizes
were unchanged. These are local observations, not a general speedup claim.

| Existing client | Baseline median | Layer pass median |
|---|---:|---:|
| Selected pipeline example | 10.83 s | 10.13 s |
| Result `map_both` | 6.64 s | 6.55 s |
| Result `map_err` | 4.30 s | 4.35 s |
| Invalid `map_both` input | 0.91 s | 0.95 s |

#### Reader, State and Writer qualification

The transport and shared-helper matrices passed all 84 source/package O0/O3
checks on the same Linux Mojo 1.2.0 toolchain. Fourteen packaged regression and
example programs cover existing local/listen/censor/state/recovery consumers;
46 tooling tests and strict documentation checks also passed. Reports retain
unchanged inputs and zero audit failures. There are 77 documented examples and
318 public exports. Layer and transport fixtures now share one mapping-only
Monad dictionary, including throwing construction and guarded target metadata.

The same bounded cold protocol compared this pass with `4641e39`. All 16
observations passed with unchanged executable sizes. The small sample shows a
higher median for the selected-pipeline client and `map_err`, with lower medians
for the other two clients; it does not establish a general performance trend.

| Existing client | Baseline median | Transport pass median |
|---|---:|---:|
| Selected pipeline example | 10.27 s | 11.15 s |
| Result `map_both` | 6.89 s | 6.67 s |
| Result `map_err` | 4.26 s | 4.49 s |
| Invalid `map_both` input | 1.02 s | 0.98 s |

#### Mapping-only capability boundary qualification

At that pass, the policy correction passed 84 source/package O0/O3 checks: all ten
unsupported recovery/observation/validation/outcome operations reject ordinary
native and library calls, while positive controls retain canonical Result,
Identity fallback, explicit Result selection and mapping-only continuation.
The same valid callback shapes appear in both rejection and acceptance controls.
Public outcome metadata also rejects unsupported mapping-only selections
without evaluating an unavailable recovery capability.

Seven packaged generic regression programs, 46 tooling tests and strict
documentation checks passed with unchanged report inputs and zero audit
failures. Public contract-based wrappers retain their `Compatible` witness;
intrinsic generic wrappers now prove absence of both stored-error capabilities.
The documentation inventory remains 77 examples and 318 public exports.

### Recovery admission consolidation

Selected recovery and observation contracts now include invocable receivers and
the family's declared adapted-handler admission. Effect observation also checks
the finishing map and combination. Conditional recovery and observation include
failure-constructor errors in native error admission. Custom dictionaries can
reject an operation without instantiating its unavailable handled carrier.

The exact-common-error predicate belongs to `_internal.errors` and is shared by
Result mapping and these contracts. Eager Boolean evaluation of total type
equalities preserves symbolic equality evidence in Mojo 1.2; projecting a
conditional common-error type into admission loses that evidence for generic
native callbacks. Runtime errors keep their existing exact projections.

This pass makes declared operation checks available at the public boundary.
Family primitives still own their branching, copying and execution rules;
additional implementation-only checks in those primitives are a subsequent
admission-audit target. No family semantics are inferred from native storage.

Qualification on Mojo 1.2.0 (`2016d0cd`) passed 92 source/package O0/O3 boundary
checks, 11 packaged regression/example programs and 31 existing rejection cases.
The 46 tooling tests and strict documentation checks also passed. All qualification
reports retained unchanged inputs and zero audit failures. New fixtures distinguish
policy rejection, missing receiver modes, finishing-operation admission and native
construction errors; the same callback shapes remain executable under an admitted
policy. The public inventory remains 318 exports and 77 examples.

### Shared checked recovery operations

Selected Pipeline recovery and observation overloads delegate to four checked
functions beside the existing contracts in `algebra.errors`. `_recover` lifts a
value handler, `_or_else_if` builds the conditional continuation, `_recover_if`
lifts its handler and delegates to that effect path, and `_observe_error` uses
the existing observation continuation for both observation modes. Contracts
supply the exact adapted types, result types, errors and admission predicates.

The generator now describes native callback admission and calls these checked
functions. It no longer constructs the recovery continuations or repeats their
family assertions in 160 generated bodies. The checked functions call the
family primitive directly: their error already equals `I.HandleError`, so no
error-widening bridge is needed. Execution remains in the existing family and
callback owners. Legacy native syntax retains its established admission and
error-probe boundary while using the same continuations and family primitive.
The reviewed public declaration inventory is unchanged by this refactor.

Qualification passed 92 source/package O0/O3 boundary checks, 11 packaged
runtime/example programs, 31 existing rejection tests, 46 tooling tests, generated
source checks and strict docs (318 exports, 77 examples). Runtime report audits
found no input/package drift or resource-contract failures.

A bounded cold-build comparison against `f4d0a00` used four unchanged clients,
two samples per version in alternating order, O3 and two compiler threads. All
16 builds/runs or expected rejections passed. Median seconds were 5.24→5.26 for
native observation, 6.52→6.19 for conditional generic recovery, 8.00→7.41 for
admission controls and 0.51→0.52 for incompatible observer errors. Median peak
RSS changes ranged from −1.7% to +2.0%; executable sizes were identical. These
small samples show no material regression in these clients, not a general
performance claim. Artifacts are in `.cache/quality-cycle11/`.

### Observation through error mapping

Plain selected `tap_err` requires observation and retention of a stored error,
not the ability to replace it with a recovered success. Mapping-only families
now use `MapErrContract` and `_map_err`, with the source family explicitly set as
the destination. The existing `_ObserveOnce` adapter borrows the error, discards
the callback result and returns the original owned error. It also exposes a
mutable invocation when its stored observer is repeatable and is copyable only
when that observer is copyable. This permits branching observers without
making consuming observers repeatable or requiring copyable stored errors.

`_TapErrSelection` chooses one dictionary before callback admission. Each
policy forwards metadata and delegates execution to an existing owner:

| Selected capability | Execution owner | Preserved semantics |
|---|---|---|
| `ApplicativeError`, including a family also implementing `ErrorMapping` | Checked recovery observation | Existing failure-constructor and recovery effects |
| `ErrorMapping` only | Checked mapping into the same family | Original error, family mapping errors, deferred timing |
| Neither capability, with native Result storage | Result observation | Existing intrinsic Result behavior and output family |

This makes observation available to `StateT[ResultFamily[E], S]` with move-only
state. The action owns state consumption and cleanup; observation adds no
rollback, extra copy or second traversal. A family's different default mapping
target cannot silently replace the selected family. `flat_tap_err` continues
to require recovery and effect combination.

The generic library callback has one overload and one public `TapErrContract`.
Native closures and thin pointers retain disjoint capability/ABI signatures.
A conditional alias of two contract structs loses their metadata fields in
Mojo 1.2; selecting execution and its exact error independently also loses
error-equality evidence in generic bodies. The selected dictionary keeps
execution, output and native error together, following the existing recovery
and outcome policy architecture. It neither erases native errors nor inserts
catch-and-convert bridges.

Generic wrappers now pass the original `I: Functor` to `TapErrContract` and
`pipeline`, removing the old capability downcast. Explicitly witnessed wrappers
can still use `downcast[I, ApplicativeError]` in both places. Mixing that witness
in the contract with the original family in the operation needs this narrow
migration; it is not accepted by Mojo 1.2's generic proof checker. Ordinary
callback calls, positional callback bindings and existing effect observation
signatures remain unchanged.

Qualification passed 236 source/package O0/O3 boundary checks, 13 packaged
runtime/example programs and 11 legacy rejection fixtures, with unchanged
inputs/packages and no audit failures. The checked cases include move-only
state/error/capture cleanup on success, failure, native exception and abandonment;
branching repeatable observers; origin-bound payloads/results/errors; changed
stored thin pointers; self-target rejection; generic component forwarding; and
recovery precedence when both capabilities are present. Tooling (46 tests),
generated-source checks and strict docs pass with 318 exports and 78 examples.
Only `TapErrContract` and `Pipeline.tap_err` declarations changed in the reviewed
public inventory.

A bounded comparison against `10e147f` used four unchanged clients, alternating
two cold O3/two-thread samples per version. All 16 checks passed and executable
sizes were unchanged. Median seconds were 6.22→6.23 for the observation example,
5.61→5.40 for native observation, 8.80→8.72 for transport mapping, and 0.57→0.67
for incompatible observer-error rejection. Peak-RSS medians changed by −0.7%
to +4.5%. The rejection cost increased by about 0.10 seconds in this small sample;
these observations do not establish a general performance trend. Artifacts are
in `.cache/quality-cycle12/` (final qualification under `qualified/`).

### Branch receiver admission through transformer primitives

`ListFamily.MapCompatible` includes the existing `RepeatableUnary` requirement;
its bind predicate inherits that rule. OptionalT and ResultT map/bind predicates
now forward admission of the exact adapted callback to the base primitive they
invoke. ResultT recovery forwards base bind admission for `_ResultGuard`, and
OptionalT recovery forwards the selected base error family's `_Handles`.
Consuming handlers and observers therefore reject through the public contracts
when those primitives branch, including mapping-only State observation over a
branching base. No new callable mode or runtime dispatch was added.

The shared `_RecoveryShape` rule owns the existing recovery membership and
payload checks for both the protocol default and transformer extensions. Its
Functor bound needs only element projections; stored-error and membership
evidence are passed separately, avoiding recursive error-capability conformance
while a transformer defines its recovery predicate.
`_CarrierBind` now checks source/result membership directly instead of borrowing
map's operation predicate. Once layer mapping admits its actual base operation,
reusing that predicate for bind would incorrectly reject a family that admits
binding but rejects mapping. A custom dictionary can keep those policies
independent by declaring `CarrierCompatible`; the legacy protocol default still
derives membership from an identity map.

Native map/bind admission now checks the actual borrowed callback adapter,
which supplies a repeatable receiver. The metadata-only error probe remains in
raised-type projections; it cannot represent receiver capabilities. List
`Piped.map` states the exact List representation and repeatable receiver in its
signature and forwards directly to the existing family primitive. This avoids
re-projecting generic element types through another checked entry. Generic
wrappers forward the same representation and receiver predicates.

Execution remains in the existing collection and transformer implementations.
Tests distinguish consuming from shared/mutable receivers, preserve move-only
payloads, keep consuming callbacks valid for Reader-based single execution,
and exercise a dictionary that rejects map while permitting bind and recovery.
The full-suite check also exposed a pre-existing generic conditional-recovery
failure, reproduced against the previous commit. `OrElseIfContract` now keeps
predicate-result equality in complete entry admission without repeating it in
the guard for carrier projection. That projection does not depend on Bool.
This preserves generic native wrappers with `R == Bool` and their positional
callback bindings, while non-Bool predicates remain rejected by `Compatible`.

Earlier family admission also changes where invalid consuming callbacks fail.
Checked entries reject at their signatures; legacy Piped and deferred execution
boundaries retain their established admission policy and use one shared message
for incompatible carriers and callback receivers. The message explicitly states
that branching callbacks must be repeatable. Rejection fixtures retain ordinary
invalid calls and expect the earlier diagnostic; no extra type bindings were
introduced to make the tests pass.

The scope is map, bind and delegated recovery admission; Cartesian combination
and traversal copying prerequisites remain separate follow-up work.

Qualification passed the full packaged suite: 683 checked programs and both
benchmark programs, with no audit failures. This run preceded the final
message-only diagnostic refresh. The final source and package passed 232 O0/O3
boundary checks, all 1,563 rejection fixtures, 46 tooling tests, generated-source
checks and strict docs (318 exports, 78 examples). Final reports have unchanged
inputs/packages and no audit failures. The full sweep identified 20 obsolete
diagnostic expectations: ten now fail at signatures, and ten legacy paths retain
an explicit repeatability explanation through the shared admission message.
Public declaration changes are limited to native map/bind admission and
`Piped.map`; parameter ordering and ordinary call syntax are preserved. Reports
and retained failed investigations are in `.cache/quality-cycle13/`.

### Shared lazy combination and branch admission

OptionalT and ResultT combination use their existing bind guards to preserve
absence or stored errors and join base carriers. `_LayerRight` owns the remaining
common work: retaining the lazy right operand, forcing it at most once, copying
its cached carrier and the combiner when the base branches, and mapping a bound
left payload over the right carrier. The guards and `_Lazy` retain their existing
ownership and execution responsibilities; no second traversal or new dispatch
mode is introduced.

Combination admission follows both base primitives that execute: bind of the
guard, and map of the right continuation. Their receiver conformances encode
branch-specific copying requirements. A single-execution base still accepts
consuming callbacks and move-only payloads/captures. The right factory need not
be copyable; only a branched cached value needs copies. Native construction errors
are checked at the continuation boundary without changing deferred run errors.
Direct List combination declares its existing repeatable-combiner and copyable
operand requirements through the same public contract. Native List map2, product
and ap forward that family predicate; generic wrappers forward the public
combination contract. Ordinary calls and positional type bindings stay intact.

Traversal and generic accumulation admission are a separate follow-up, because
their accumulator policies have different copying requirements.

Qualification on Mojo 1.2.0 includes 100 source/package O0/O3 boundary checks,
1,578 rejection fixtures, 46 tooling tests, generator consistency, and strict
public documentation checks (318 exports and 78 examples). The complete suite
passed 687 checked programs and two benchmark programs before the final
compile-time diagnostic refresh; the refreshed package passed the boundary and
rejection gates. All successful reports retained unchanged inputs and no audit
failures. Runtime controls cover Cartesian order, mutable combiner state, lazy
right production and skipped branches; 24 ownership scenarios cover consuming
captures, abandonment and exact native exceptions. Ordinary native, callable and
generic fluent calls are maintained controls. The first rejection run found two
legacy diagnostic regressions, now fixed in their assertion owners; its raw
report remains alongside final evidence in `.cache/quality-cycle14/`.

### Source-aware traversal and loop admission

Traversal and collection have separate admission responsibilities. A source's
`TargetCompatible[G, V, F]` describes the target operations its traversal uses.
The default retains the historical target collection predicate for custom
source families. Identity invokes the producer once; Optional and Result invoke
it at most once and map a shape wrapper over its result. They do not inherit
Cartesian collection's copy or repeatability requirements. NonEmptyList checks
collection of its transferred List and the map that restores nonempty shape.

`TraverseContract.TargetCompatible` forwards this source-owned decision.
`CollectCompatible` retains its direct collection meaning; `Compatible` and
`FamilyCompatible` use the target operations selected by the source. A wrapper
abstract over both source and target must forward `S.TargetCompatible[G, V, F]`
in place of `G.CollectCompatible[V, F]`, or forward the combined public contract.
Ordinary calls and explicit positional bindings keep their syntax.

The private `_LoopCompatible[V, F, K]` belongs to the accumulator loop owner.
Its permissive default preserves custom dictionary behavior; List declares its
actual repeatable producer, copyable accumulator/item and compatible native
error requirements. OptionalT and ResultT forward the exact wrapped accumulator
to the base loop. Collection selects append; discarded traversal selects discard.
The source's payload need not be copyable, and the producer's captures are not
copied. Deferred construction errors and later execution errors remain separate.

Native entry points admit the actual callback adapter. Error-only probes still
project errors and do not claim callable receiver conformances. Free iterable,
iterator, legacy fluent and selected methods forward the same operation policies;
their bodies still delegate to the existing source traversal or target loop.

This pass exposes the existing loop requirements without changing copying,
pulling, short-circuiting or branching algorithms. Other custom loop owners may
override `_LoopCompatible` to describe additional prerequisites.

Single-value source admission also retains the existing requirement that the
target's pure and mapped branches have the same carrier type. Targets with
different deferred representations reject at the checked boundary. Supporting
those targets through the existing family branch join is a separate extension;
this pass keeps traversal output types and branch execution unchanged.

Mojo 1.2 generic admission also needs the final carrier/error type equalities
to use eager Boolean conjunction. Receiver, carrier and map checks guard those
projections first. Both free and selected wrappers can forward the combined
contract when the producer type itself depends on the target dictionary;
ordinary invalid output shapes still return false metadata.

Qualification passed all 693 packaged suite programs (691 checked clients and
two benchmarks), all 1,596 rejection fixtures, and 88 source/package O0/O3
boundary checks. A final generic-proof refinement and added metadata controls
then passed a fresh 84-check traversal matrix and all 127 traversal rejection
fixtures. These final runs had unchanged inputs/packages and no audit failures.
The full suite and rejection run precede that Boolean-only refinement; traversal
execution is unchanged. Tooling passed all 46 tests after updating the reviewed
example count, and documentation covers 318 exports and 79 executable examples.
Evidence is retained in `.cache/quality-cycle15/qualified2/` and
`.cache/quality-cycle15/final/`; the earlier interrupted documentation run is
marked incomplete rather than counted as qualification.

### Identity ownership in the callable layer

`Identity[T]` is implemented in `callables/_identity`, alongside the callable
protocol it implements. Composition, algebra, data and iteration import that
one implementation. `fp.functions.Identity` and the existing composition-module
import remain the same public type; empty `flow[T]()` and `compose[T]()` still
return it. The callable operator delegates to `call`, so owned identity has one
execution method and preserves the exact payload and its origins without copying.

Moving this leaf removes the dependency from Result storage through composition
into the pipeline execution machinery. The module graph remains acyclic, and
the architecture test now rejects any dependency from Result storage or the
identity implementation into `functions`. Public names, signatures and parameter
order are unchanged; the reviewed declaration provider moves to the callable
module. This dependency cleanup does not claim a measured compilation speedup.

Reference rendering and completeness checks now share the same public-owner
lookup. They prefer the provider's package only when it actually exports that
name; otherwise they select an existing public export. Moving an implementation
to a private lower layer cannot create a nonexistent reference link or exempt
its docstrings from validation. Existing re-export links retain their owners.

Qualification passed 694 packaged suite programs (692 checked clients and two
benchmarks), four source/package O0/O3 identity checks, and 39 composition
rejection fixtures, with unchanged inputs and no audit failures. Ownership
controls cover empty flow/compose, public and legacy imports, move-only values,
exact `Never` and borrowed origins. The documentation-only routing fix followed
that suite and is covered by two additional regressions, all 48 tooling tests,
and strict documentation validation for 318 exports and 79 examples. Evidence
is retained in `.cache/quality-cycle16/qualified/`.

### Shared applicative branches for single-value traversal

Optional and Result traversal now use the same branch guards as transformer
bind and recovery. Those guards live in `algebra/_branches` and require only
Applicative: selecting a branch needs `pure` and the family's existing join,
not monadic bind. Result still owns the consuming fold, and the continuation
invokes the producer once and maps the existing shape wrapper. There is no new
dispatch mode, traversal loop or representation for native values.

The target's `_JoinCompatible` owns admission for the pure and mapped branches.
Its default requires one carrier type. Reader and State admit their own actions
with matching payloads; Writer and the Optional/Result layers forward the actual
base carriers. Reader's origin-dependent run compatibility remains checked at
the actual run origin. No synthetic origin or erased native error is substituted.

This extends single-value traversal to deferred targets whose pure and mapped
representations differ. A present/successful source calls its producer during
construction, at most once; absence or a stored error skips it. The produced
action remains deferred. Producer exceptions arise during construction, while
action exceptions arise only when run, each with its exact native error type.
Dropping a pending result consumes its captures and payloads exactly once.

The earlier same-carrier limitation is therefore removed. Built-in eager target
results retain their types. Generic wrappers should return `TraverseContract.Out`
or the source's `Traversed` projection rather than assume the result is exactly
`G.Mapped`: custom targets with their own branch join now control that result as
they already do for transformer operations. Ordinary calls and positional type
bindings keep their existing syntax; no additional callback adapter is needed.

Qualification on Mojo 1.2.0 passed 104 source/package O0/O3 boundary checks, all
699 packaged suite programs (697 checked clients and two benchmarks), all 1,597
rejection fixtures, and 48 tooling tests. Reports retain unchanged inputs and
packages and no audit failures. Strict documentation validation covers 318
exports and 80 executable examples. Public export names, providers and signatures
are unchanged.

Controls cover native/free/selected calls and sequence, generic contract
forwarding, deferred Writer logs, actual Reader error origins, nested Reader
borrows, and 32 ownership scenarios with move-only inputs, captures, stored
errors and state. Escaping a local borrowed payload rejects normally. The two
former deferred-shape rejection fixtures now test a genuinely incompatible
Reader/State target, while successful Reader traversal is a maintained runtime
case. Evidence is retained in `.cache/quality-cycle17/qualified-main/`.

### Linear collection admission

Identity, Optional, Result and Validation declare the requirements of their
existing repeated collection loops. A shared predicate checks an iterable or
iterator source, its item type, a repeatable producer and compatible native
exceptions. Custom accumulators additionally require the produced item to match
and, for validation, compatible diagnostic-policy exceptions. These linear
loops impose no copying on payloads, captures or accumulator state.

Collection combines independently guarded carrier and producer predicates with
eager Boolean conjunction. This preserves generic caller evidence without
requiring structural bounds or reconstructing an append accumulator through the
callback's result. Explicit policy error types keep the original native-error
equalities visible. Result binding uses carrier membership directly, preserving
consuming callbacks independently of repeated collection.

A custom Traversable whose implementation maps or combines a fixed number of
effects declares those operations in `TargetCompatible`; the default describes
collection. The maintained custom single-Result and two-value examples now do
so. Ordinary calls retain their syntax. Invalid consuming callbacks in repeated
traversal reject at overload selection instead of inside the execution loop.

Qualification on Mojo 1.2.0 passed 24 source/package O0/O3 boundary checks
and 701 packaged programs (699 checked clients and two benchmarks). All 1,601
negative calls reject; the full run matched 1,600 diagnostic expectations and
identified one further obsolete body-assertion expectation. That fixture now
expects overload rejection and is verified separately without changing its call.
The earlier six traversal expectations were updated for the same reason.
Inputs and packages remained unchanged within each run; the full rejection
report retains the two audit findings caused by that stale expectation.
Evidence is retained in `.cache/quality-cycle18/qualified-main/` and the focused
follow-up under `.cache/quality-cycle18/diagnostic-followup/`.

### Shared first-error accumulator

Result transformer layers now use `_ResultAccumulator[K, _FirstError[E]]`, the
same owner as native Result collection. The private `_ResultAcc` spelling is an
alias, so there is one implementation of start, liveness and first-error
combination. Native errors, early termination and ownership remain unchanged.

The ownership control exercises all 16 combinations of left/right stored
errors, live/stopped accumulation and a raising combine, plus a raising start.
It checks the exact native error, selected result, liveness and combine call
counts, and one destruction for each move-only input. A pre-change versus
post-change trace comparison also retained destruction order. Optional's loop
is deliberately separate: routing it through the existing Optional accumulator
would introduce an additional observable liveness query.

Qualification passed four source/package O0/O3 ownership checks, 34 packaged
traversal programs, all 128 traversal rejection fixtures and 48 tooling tests.
Reports retain unchanged inputs and packages and no audit failures. Strict
documentation checks cover 318 public exports and 80 examples. Evidence is in
`.cache/quality-cycle19/qualified-main/`; public syntax and signatures are
unchanged.

### Writer collection follows base loop admission

Writer's collection admission now forwards the actual `_UnwrapResult` producer
and `_WriterAcc` accumulator to the base's `_LoopCompatible` predicate. It also
checks the log policy and accumulator's original native errors before their
common error projection. Carrier membership alone cannot describe repeated
execution or the copies needed by a branching base.

Identity, Optional and Result bases retain move-only inputs, outputs, logs and
captures. List's Cartesian base requires only the copies its existing loop
performs. Consuming callbacks remain valid for single-value source traversal;
repeated collection rejects them before executing the loop. Generic wrappers
forward the existing `TraverseContract.Compatible` predicate, with no new
callback annotations. The algorithm, log order and native representations do
not change.

Qualification passed all 28 source/package O0/O3 boundary checks, 705 packaged
programs (703 checked clients and two benchmarks), 1,605 rejection fixtures,
and 48 tooling tests. Inputs and packages remained unchanged and reports have
no audit failures. Strict documentation checks cover 318 exports and 80
examples. Evidence is in `.cache/quality-cycle20/qualified-main/`.

### Concrete payload constructors for pure

The public `pure[I](value)` operation and internal family composition now call
one `_pure` owner. Applicative's private `_PureAction[A]` selects an existing
Unary callable whose argument is `A`, result is exactly `Pure[A]`, and error is
`Never`. The default adapts the dictionary's static `pure`, preserving existing
custom families. Writer supplies `_WriterPure`, which creates the empty log
before injecting the native `(log, value)` tuple into the base; its concrete
static `pure` delegates to that same owner. No callback annotation, storage
wrapper, copied payload or new public argument is introduced.

This separates payload specialization from generic method-witness lookup. Mojo
1.2 fails that lookup for an abstract Writer/Optional dictionary whose produced
carrier nests a native Tuple. A reduced program reproduces the failure without
importing this library. Fixed-field records avoid it but would change native
storage; type projections and alternate trait bounds do not solve it. Direct
abstract `I.pure` calls retain that compiler limitation. Public `pure[I]` and
library composition now use the concrete callable path, including Reader,
State, Optional and Result layers around Writer/Optional.

The constructor retains exact return types, borrowed origins, native `Never`,
log initialization order and move-only payloads. Maintained controls cover
four Writer bases, nested effects, discarding pending actions, owned state,
and rejecting a borrowed local that would escape. Ordinary concrete dictionary
calls and all existing positional public bindings remain available.

Qualification passes 20 source/package checks at O0/O3, all 710 programs
(708 checked programs and two benchmarks), and all 1,606 rejection fixtures.
The reports retain unchanged inputs and no audit failures. The added executable
example raises the reviewed documentation inventory to 81 examples; its old
80-example tooling assertion is updated separately from the compiler checks.
Evidence is in `.cache/quality-cycle21/qualified-main2/`, with the corrected
tooling and final documentation checks alongside it.

### Primitive operation error forwarding

The fundamental protocol module now owns `_map_as`, `_flat_map_as`, and
`_map2_lazy_as`. Its default applicative and monadic loops use those same
adapters as derived operations and effect layers; `_adapt` retains compatible
internal imports. Each adapter forwards one native operation and widens only
`Never` to the caller's declared error. Existing compatibility proofs remain
at each call site, including the loops' exact carrier-type assertions.

This removes four parallel try/propagate implementations without introducing
another operation protocol. Loop order, lazy pulls, liveness checks, ownership,
and public signatures remain the responsibility of their existing owners.

Qualification passes all 232 source/package checks at O0/O3, 39 packaged
algebra programs, all 48 tooling tests, and the generated-signature check.
The compiler reports retain unchanged inputs and no audit failures. Strict
documentation checks retain 318 exports and 81 examples. Evidence is in
`.cache/quality-cycle22/qualified-main/`.

### Mapping native product components

`_MapPair` in the callable product module owns moving a native pair apart,
mapping one component, and retaining the other unchanged. State's `_MapFirst`
and Writer's `_MapValue` and `_Censor` are aliases selecting the component.
The adapter preserves the exact native tuple type and each component's origin;
the untouched component never needs to be copyable.

Consuming invocation moves the callback. Repeated invocation borrows it through
the existing exclusive receiver view and runs the same mapping implementation,
retaining callback mutations across calls. The aliases retain their existing
constructor field and receiver/copyability contracts. Maintained controls cover
native errors, both component positions, distinct borrowed result/error origins,
and rejection of an escaping local borrow. Twelve old/new destruction traces,
including two successive calls through one mutable callback, match exactly.

Qualification passes 12 source/package checks at O0/O3, 15 Writer programs,
24 State programs, 132 generic clients, all 48 tooling tests, and the
generated-signature check. Reports retain unchanged inputs and no audit
failures. Strict documentation checks retain 318 exports and 81 examples.
Evidence is in `.cache/quality-cycle23/qualified-main/`.

### Accumulators reuse product operations

State's `_FoldState` now combines the carried accumulator through `_BindFirst`
and `_MapPair`; Writer's accumulator delegates the pair combination to
`_WriterCombine`. Their outer policies retain liveness, initialization, and
receiver ownership. Writer still checks `K.live` exactly once before combining
logs or values, including the stopped path. State still copies its saved
accumulator only for a repeated call and does not become a copyable callback.

This leaves product movement and callback invocation with their existing
owners. Twelve old/new traces match for log failure, accumulator failure,
stopped accumulation, and repeated State folds. Maintained controls check the
native error codes, destruction order, and retained initial accumulator across
two calls. No public API, native storage, or copyability requirement changes.

Qualification passes four source/package checks at O0/O3, 15 Writer programs,
24 State programs, 34 traversal programs, all 48 tooling tests, and the
generated-signature check. Reports retain unchanged inputs and no audit
failures. Strict documentation checks retain 318 exports and 81 examples.
Evidence is in `.cache/quality-cycle24/qualified-main/`.

### Repeated Writer receivers share consuming execution

Writer binding and pair combination now execute their repeated callbacks
through the same implementation as consuming calls. `_WriterStep` borrows its
callback with the existing unary receiver view; `_WriterCombine` uses the
corresponding binary view in the callable receiver module. These views delegate
receiver selection to `call_repeated` and preserve the callback's exact argument,
result, and native error types. No owned callback state is copied.

The consuming implementation continues to own tuple movement, log ordering,
and failure cleanup. Sixteen old/new traces match, including two calls through
one mutable callback, log failures before value combination, and callback
failures before log prefixing. Maintained tests check move-only captures,
distinct borrowed result/error origins, exact native errors, and rejection of
an escaping local. Existing receiver and log-copyability contracts remain.

Qualification passes all 12 source/package checks at O0/O3, 17 Writer
programs, 24 State programs, 132 generic clients, all 48 tooling tests, and
the generated-signature check. Reports retain unchanged inputs and no audit
failures. Strict documentation checks retain 318 exports and 81 examples.
Evidence is in `.cache/quality-cycle25/qualified-main/`.

### Derived and native entries share primitive forwarding

The shared primitive error adapters also serve native map/bind entries,
conditional effects, mapped effect folds, traversal postprocessing, and n-ary
products. Nine additional try/propagate implementations now delegate to the
protocol owner. Call sites retain explicit compatibility proofs, including
native callback error-shape equalities and n-ary carrier-type assertions.

Public native signatures and positional bindings are unchanged. Product
operands still move into optional slots before sequencing, so an early error
cleans unvisited operands. Lazy combination order, deferred execution, borrowed
callback lifetimes, and exact native error origins remain unchanged. Prototype
checks cover 44 source/package n-ary checks at O0/O3, 34 traversal programs,
five effect-query programs, and 132 generic clients.

The full checkpoint passes 44 source/package checks at O0/O3, all 715
programs (713 checked programs and two benchmarks), all 1,608 rejection
fixtures, all 48 tooling tests, and the generated-signature check. Compiler
reports retain unchanged inputs and no audit failures. Regenerating the API
metadata produces no changes; strict documentation checks retain 318 exports
and 81 examples. Evidence is in `.cache/quality-cycle26/qualified-main/`.

### Writer log operations use the monoid accumulator

Writer's empty-log and log-combination adapters now reuse `_start_as` and
`_combine_as` through the existing `_Combine[W]` monoid accumulator. Prefixing
a log uses the same bound accumulator and native product mapper as other
product operations. The prefix wrapper retains its field, receiver modes, and
copyability, including the original copy point before a repeated invocation.

Twenty-two old/new traces match across Writer binding, combination, and direct
prefixing. The maintained prefix control checks consuming move-only logs,
consuming copyable logs without copying, and exactly one copy per repeated
call. Native failure codes and destruction order are unchanged on each path.

Qualification passes four source/package checks at O0/O3, 17 Writer programs,
34 traversal programs, all 48 tooling tests, and the generated-signature check.
Reports retain unchanged inputs and no audit failures. Strict documentation
checks retain 318 exports and 81 examples. Evidence is in
`.cache/quality-cycle27/qualified-main/`.

### Traversal forwarding and computed-right combination

The protocol module now owns traversal's existing native-error forwarding
adapter. Native traversal entries and traversal postprocessing use that same
owner; the traversal module retains its internal re-export. Existing callback
error-shape checks remain at native entry points.

`_map2_as` owns adapting an already-computed right operand to the canonical
value thunk and forwarding combination errors. Public `map2` delegates to it,
and `ap` delegates to `map2` with the existing application callable. All three
retain their selected family's admission, evaluation order, exact output and
error types, and ownership of skipped right operands. Public signatures and
positional bindings are unchanged.

Qualification on Mojo 1.2.0 passed 396 source/package checks at O0 and O3,
34 traversal programs, 39 algebra programs, 132 generic clients, all 48 tooling
tests and generated-source verification. Compiler reports retained unchanged
inputs and no audit failures.

### Reader recipe requirements at the run boundary

Reader recipes now carry a private origin-dependent requirement through maps,
binds, combinations, collection, choice, hoisting and local environments. The
checked free `run` entry combines that requirement with the existing base-carrier
check at the actual environment origin. A producer's raised pointer and a child
recipe's environment-dependent raised pointer must therefore have compatible
origins before the call is admitted; selecting one symbolic common error must
not hide the child's requirement. Existing custom Reader actions inherit a true
default and keep their current trait contract.

Collection admits repeatable producers, and its run checks the selected base's
actual loop requirement with the adapted producer. A single-value Optional
traversal still accepts a consuming producer: it uses bind, not the collection
hook. Construction does not speculate about a custom base's source requirements
or invent an environment origin before a run exists.

`local` also checks the nested requirement at its existing empty and universal
origin witnesses. Those witnesses are declaration checks, never execution
origins or permission to relabel a borrow. The inner run still checks the fresh
local environment. This rejects a hidden child-error mismatch even when the
recipe's final output and selected error appear independent of that environment.

Public call syntax and positional bindings are unchanged. Mojo 1.2 does not
support a `where` clause on the Reader trait's `run` method, or a stronger clause
on its implementations. Accordingly, the free `run` and `local` entries own
signature admission; primitive trait methods retain their preconditions. This
pass propagates declared recipe requirements, rather than claiming complete
admission for arbitrary custom bases or the dependent-fold hook.

Prototype qualification passed 20 source/package checks at O0 and O3, all 717
runnable programs (715 checked programs and two benchmarks), and all 1,612
rejection cases with unchanged inputs and no audit failures. Generated sources
matched. The prototype's tooling snapshot retained an obsolete 80-example count;
main-tree qualification uses the already-corrected 81-example inventory. Main-tree
qualification passed 20 source/package checks, five Reader programs, 34 traversal
programs, 132 generic clients, all 48 tooling tests and generator verification.
Compiler reports retained unchanged inputs and no audit failures.

### Repeated Reader receivers share consuming execution

A repeated Reader continuation now borrows its mutable callback through the
canonical unary receiver view and runs the existing consuming continuation.
The environment pointer keeps its original origin. The callback is neither
copied nor consumed by the view; each repeated call mutates the same receiver.
The consuming implementation remains the owner of producer invocation, child
recipe admission, error forwarding and running the produced action.

Eight baseline/candidate traces matched for consuming and repeated calls,
producer failure, child-run failure, exact error precedence and owned-capture
cleanup. The maintained ownership program checks those traces. Prototype
qualification passed 24 source/package checks at O0 and O3, 17 Writer programs,
34 traversal programs and 132 generic clients with unchanged inputs and no
audit failures. Public receiver capabilities and call syntax are unchanged. Main-tree
qualification repeated those checks and passed all 48 tooling tests and generated
source verification; compiler inputs remained unchanged with no audit failures.

### Dependent fold error forwarding

The protocol module owns one native-error adapter for the dependent `_fold`
primitive. Effectful reductions, State traversal, and deferred Reader/State
folds delegate through it. The selected family still owns source advancement,
liveness, accumulator state, callback order and the exact result representation;
the adapter only checks and forwards the native raised type. No callback,
source or accumulator is copied by this boundary.

Qualification passed 232 source/package effect-query checks at O0 and O3,
24 State programs, 34 traversal programs and 132 generic clients, with unchanged
inputs and no audit failures. Six standalone O0 programs also passed. The
integrated library matches the qualified implementation; comparison found only
earlier constructor documentation updates in two files. A fresh main-tree
precompiled package and its O3 native client passed. Public signatures and
positional bindings are unchanged.

### Cached lazy operand error forwarding

The lazy right-operand owner now forwards thunk invocation through the canonical
consuming error adapter for both transfer and repeated-copy access. Its private
`copy_value` accepts the caller's compatible raised type, defaulting to the
thunk's exact error. State and Optional/Result transformer continuations use
that boundary and remove their duplicate catch-and-rethrow blocks.

Construction remains lazy. The first request produces and retains the value;
repeated requests copy that retained value, and consuming access transfers it.
The callers still copy their combining callback after obtaining the right
value. Skipped operands, producer failure and abandonment retain their original
cleanup and error precedence. No public call syntax changes.

Eight baseline/candidate traces matched for unused operands, direct transfer,
repeated copying, cached transfer, abandonment and producer failure. Maintained
controls also exercise a non-raising producer in a raising caller and exact
borrowed output/error origins. Qualification passed four source/package checks
for those controls and 76 combination admission checks at O0 and O3, 24 State
programs, six layer programs, seven combination programs and 132 generic clients.
All compiler reports retained unchanged inputs and no audit failures. Integrated
library comparison found only earlier constructor documentation updates in two
files; the implementation matches the qualified prototype.

### Declared fold admission and generic forwarding

`FoldContract[I, V, F]` exposes input equality, output carrier membership,
family admission, the exact result and the construction error for a free
`fold_effect` call. A generic wrapper forwards its single `Compatible`
predicate and uses `Out` and `Error`; the same proof works for `Piped` folds.
It stores no runtime state and does not adapt or invoke the callback.

The existing private fold descriptor moves to the contract module and remains
re-exported under its existing internal name. The all-live accumulator policy
moves to the protocol owner. Generated free, fluent and selected effect entries
use the descriptor's family requirement instead of discovering invalid native
fold receivers only inside execution.

The four native eager families declare the default driver's precise requirements:
repeatable preparation and steps, exact source/accumulator/output types and
compatible native errors. List also requires copyable prepared items because a
step can be invoked on several accumulator branches. Identity, Optional and
Result keep move-only items. One helper owns these checks; native carrier type
and branching policy remain declarations of each family.

Custom families inherit permissive fold metadata and keep their existing
implementation contract. This pass does not claim complete admission for
custom or deferred family internals. Describing a complete family through its
own Monad-bounded helper caused recursive conformance resolution on Mojo 1.2;
passing the native carrier and branching policy avoids that cycle without
compiler internals or weaker ownership checks.

The added descriptor is a public API addition. Ordinary call syntax, positional
bindings and runtime execution remain unchanged. Generic wrappers that forward
only partial preconditions can use `FoldContract.Compatible` to forward the
complete checked free-call requirement.

Qualification passed all 721 positive programs. The full rejection run rejected
all 1,616 fixtures without crashes or timeouts; three expected diagnostic strings
still named the old execution-body assertion. Those fixtures now require the
normal call-boundary diagnostic and passed all 12 source/package checks at O0
and O3. The original report is retained rather than rewritten. The remaining
1,613 fixtures passed their declared diagnostics in that full run. Twenty new
contract boundary checks and four checks for the earlier search diagnostic also
passed. Generated sources and all 48 tooling tests passed; the strict docs build
validated 319 exports and 82 examples, and the new example passed all four routes.
A fresh integrated package and its O3 native client passed with unchanged inputs.

### State recipe requirements at execution

State actions carry a private execution requirement through mapping, bind,
combination, traversal, dependent folds, choice and hoisting. The checked free
`run` entry uses the public `StateFamily.RunCompatible[V]` predicate. Built-in
State families combine carrier membership with the recipe's requirement;
custom families and actions keep their existing contract through defaults.

A State recipe's requirements describe its actual base operations and native
error combination. A traversal asks the selected base's fold admission about
its adapted step, without imposing List's branch-copy rule on linear families
or inventing source requirements for custom fold implementations. Reader's
dependent-fold recipe now forwards that same base requirement at its actual
run origin.

Ordinary calls and positional bindings are unchanged. Generic State runners
should forward `I.RunCompatible[V]` in place of `I.CarrierCompatible[V]`: carrier
membership alone cannot prove that every nested operation can execute. A runner
bounded by the public StateAction trait can still return `V.Out` and raise
`V.Error`, without private projections or extra callback annotations. Trait
methods keep their existing unconstrained signatures and primitive preconditions;
the checked free entry owns signature admission.

The maintained controls distinguish producer and child-action error origins,
propagate incompatibility through map and bind, reject a consuming producer in
a multi-element native fold, and preserve consuming single-value traversal.
They also verify a generic runner and exactly-once destruction of move-only
state. Requirements do not add runtime allocation, invocation or copying.

Eight maintained generic helpers now forward RunCompatible in place of carrier
membership; their value and ownership assertions are unchanged. All eight passed
focused O0 checks, and the fresh full suite passed all 722 positive programs.
The 24 source/package execution checks at O0/O3 also passed. The full rejection
run rejected all 1,621 fixtures without crashes or timeouts: 1,614 matched their
declared diagnostics, while seven retained earlier diagnostic spellings. Three
were the preceding fold pass's expectations; four now identify run admission.
All seven corrected fixtures passed 28 fresh source/package checks at O0/O3.
The original failed reports remain available. Generated sources, all 48 tooling
tests and the strict documentation build passed.
The integrated package and O3 client passed with unchanged inputs. One tooling
run encountered an intermittent child-reaping test failure; the focused resource
checks and a fresh full 48-test run passed, with the failed log retained.

### State traversal delegates directly to the fold owner

State collection executes through the canonical dependent-fold adapter directly
from its run method. The private forwarding method is removed, and the recipe's
execution requirement sits with its other metadata. Reader, layer and effect
modules also drop imports made obsolete by earlier invocation consolidation.

This pass changes no public signatures or operation order. The accumulator is
initialized before the function and source move into the same fold call; the
base family retains liveness, state threading, errors and ownership. Six focused
O0 programs passed, followed by 24 State execution boundary checks at O0/O3,
25 State programs, 34 traversal programs, two layer programs and six Reader
programs. The categories overlap. All reports retained unchanged inputs and no
audit failures; generated sources and all 48 tooling tests passed.

### Listening reuses carrier and product operations

Lifted listening invokes the selected capability through the existing carrier
operation adapter. It then uses the existing native pair mapper and owned
pairing callback to place the observed log beside the payload. The selected
capability still owns listening; the product layer owns splitting and moving
pairs. This removes a second native-error catch and nested product-movement
implementation without adding another capability or public wrapper.

Listening still runs before mapping. A listening failure skips mapping, while
a mapping failure preserves its own error. Both pair layouts retain their exact
native origins and move each owned value once. The internal rearrangement adds
no log-copy requirement beyond the selected capability's contract.

Eight baseline/candidate traces match for both layouts, repeated invocation,
listening failure and mapping failure. Maintained controls also cover widening
a non-raising listen into a raising mapper and three distinct borrowed output
origins. Qualification passed four source/package ownership checks at O0/O3,
17 Writer programs, 20 capability programs, 133 generic clients and 19 Writer
capability rejection fixtures. Reports retained unchanged inputs and no audit
failures; generated sources and all 48 tooling tests passed.

### Traversal reuses loop and collection forwarding

The protocol module owns one native-error adapter for the independent `_loop`
primitive. Default collection and payload-discarding traversal delegate through
it, retaining the selected family's exact symbolic result and error. The family
still owns advancement, liveness, accumulation and deferred execution.

NonEmptyList traversal converts its owned source once and delegates to the
existing List traversal boundary before restoring non-empty successful results.
List traversal still invokes the target's own `collect`, including custom
overrides. No loop is replaced by representation inspection, and no payload,
callback or source is copied by these adapters. Public signatures are unchanged.

Four focused O0 programs passed. Qualification then passed 76 source/package
accumulation checks at O0/O3, 34 traversal programs, five NonEmptyList programs,
133 generic clients, all 48 tooling tests and generated-source verification.
All compiler reports retained unchanged inputs and no audit failures.

### Generated fold signatures use the public contract

Free, Piped and iterator `fold_effect` entries now express source, result and
family admission through `FoldContract.Compatible`. The native Array Piped
route also retains its exact Array shape check. The explicit raised-error
compatibility check remains separate because callers may supply that binding.

The generator no longer repeats the contract's individual predicates across
these entries. Parameter order, native callback adaptation, output/error types
and runtime forwarding are unchanged. Existing generic callers can still
provide the individual requirements or forward the public contract as a whole.
Selected staged reductions retain their existing receiver constraints.

Five focused O0 programs passed, including generic forwarding, thin callbacks,
owned inputs and the public FoldContract wrapper. Qualification passed 20
source/package contract checks at O0/O3, five effect-query programs, 133 generic
clients, 15 effect-combinator rejection fixtures and 63 fold rejection fixtures.
The rejection categories overlap. Reports retained unchanged inputs and no
audit failures. Generated sources, all 48 tooling tests, refreshed API metadata
and strict documentation checks passed.

### Semigroup invocation preserves callback lifetimes

A stateless binary callable exposes Semigroup combination to the existing
callable invocation boundary. Public combination, monoid accumulation,
Validation and Ior reuse it. It introduces no identity requirement, payload
copy or error conversion; the selected policy still owns ordered combination.
The shared binary adapter forwards its exact native error where the surrounding
operation admits that error.

Removing a local catch initially changed when an unused Validation success
callback was destroyed. The accepted implementation explicitly retains that
callback until diagnostic combination finishes, including the raising path.
This preserves the original ownership order without duplicating error forwarding.
The rejected prototype and its trace mismatch remain available as evidence.

All 27 baseline/candidate traces match across direct combination, optional
Ior diagnostics, every Validation branch pairing, policy and callback failures,
and ordinary first-error Result behavior. Maintained checks also retain borrowed
result and native-error origins. Qualification passed four source/package checks
at O0/O3, all 724 positive programs and all 1,621 rejection fixtures, with unchanged
inputs and no audit failures. Generated-source verification, all 48 tooling tests
and strict documentation checks passed.

### Fold output and error projections use the same public contract

Generated free, Piped and iterator `fold_effect` signatures project both their
result and native error through `FoldContract`, alongside its admission predicate.
Generic clients and the API reference therefore name one contract for the whole
operation. The private fold recipe remains the execution owner. Native callback
adaptation, explicit error bindings, parameter order and exact types are unchanged.

Five focused O0 programs passed. Qualification passed 20 source/package contract
checks at O0/O3, five effect-query programs, 133 generic clients, 15 effect-combinator
rejection fixtures and 63 fold rejection fixtures. Categories overlap. Reports
retained unchanged inputs and no audit failures. Generated sources, all 48 tooling
tests, refreshed API metadata and strict documentation checks passed.

### Optional semigroup accumulation has one policy owner

Optional combination now lives with the shared accumulation policies. Consuming
`combine_all_optional` terminals and Ior diagnostic merging use that same policy:
an empty accumulator takes the first value, while two present values use ordered
Semigroup combination. Ior retains its absent-right fast path. Neither operation
requires a Monoid identity, copies values or changes native error types.

All 35 baseline/candidate traces match. Maintained terminal checks cover empty,
single-element and multi-element inputs, returned presence and first value,
policy failure, and destruction of elements that were never visited. Qualification
passed four source/package ownership checks at O0/O3, 10 terminal programs,
six reduction programs, 16 Ior programs, five parallel-validation programs and
133 generic clients. Rejection groups passed 31 terminal, 32 reduction, 18 Ior and
15 accumulation fixtures; categories overlap. Reports retained unchanged inputs
and no audit failures. Generated sources, all 48 tooling tests and strict
documentation checks passed.

### State recipes separate admission from error projection

State map, bind, combination and hoist bodies use their existing execution
contract for child admission, without asserting the same child requirement
again. Hoist likewise obtains operation admission from its recipe contract.
Family, payload and explicit native-error projection checks remain intact.
Imports left behind by earlier forwarding consolidation are removed.

An isolated attempt to remove common-error projection assertions was rejected:
Mojo 1.2 could not prove the constrained calls from `_CommonErrorCompatible`
alone. Selecting a common error and proving that each operation can raise it
remain distinct native proof obligations. The accepted implementation documents
that boundary rather than weakening the adapters or introducing casts.

Seven focused O0 programs passed. Qualification passed 24 source/package State
execution checks at O0/O3, 25 State programs, 34 traversal programs and
133 generic clients, followed by all 43 State-related rejection fixtures. Categories
overlap. Reports retained unchanged inputs and no audit failures. Generated
sources, all 48 tooling tests and strict documentation checks passed.

### Conditional failure construction reuses its native adapter

Ensure and conditional recovery delegate fallible failure construction to the
existing family failure adapter. Their continuations still own branch selection
and joining; the adapter alone forwards the family's native construction error.
An unmatched stored error is reintroduced through the selected family's `fail`,
including custom implementations. A rejected ensure value still reaches its
error factory before failure construction. Public signatures are unchanged.

All 28 baseline/candidate traces match, covering predicate, factory, handler and
family-construction failures, accepted values, retained stored errors and skipped
callbacks. Maintained checks assert exact errors, outcome branches and destruction
order for owned callback captures and payloads. Qualification passed four
source/package ownership checks at O0/O3, three family-ensure programs, four
family-conditional programs, five shared-outcome programs and 133 generic clients.
Rejection groups passed 32 ensure, 35 conditional and 33 recovery fixtures;
categories overlap. Reports retained unchanged inputs and no audit failures.
Generated sources, all 48 tooling tests and strict documentation checks passed.

### Outcome sequencing avoids redundant error traps

Redeem and whole-outcome observation sequence the existing materialization,
map and bind adapters directly. Each adapter already raises the selected exact
native error, so the outer catch-and-rethrow blocks are unnecessary. The native
error compatibility proofs, family operations and callback timing remain intact.
This removes a second propagation layer without changing the public API.

All 48 baseline/candidate traces match for ordinary and effectful redemption,
whole-outcome observation, construction failure before callback invocation,
bind failure, restoration failure and callback errors. Maintained checks preserve
owned payload and callback cleanup order on those paths. Six focused O0 programs
passed. Qualification passed four source/package ownership checks at O0/O3,
four family-outcome programs, five attempt-tap programs, five shared-outcome
programs, 133 generic clients, 54 outcome rejection fixtures and 23 attempt-tap
rejection fixtures. Categories overlap. Reports retained unchanged inputs and
no audit failures. Generated sources, all 48 tooling tests and strict
documentation checks passed.

### Result combination reuses callable binding and mapping

After producing the right operand, Result combination binds the left success
through the existing first-argument callable and maps that callable through the
right Result. Result's map continues to own success selection and error retention.
The duplicate left-payload context and native callback bridge are removed.
Lazy-right evaluation, single-use callbacks and native errors are unchanged.

All 59 baseline/candidate traces match. The 24 added owned-payload cases cover
every success/error pairing for ordinary Result and accumulating Validation,
callback failure and policy failure. Maintained checks assert the returned branch,
retained owner, exact error and destruction order. Qualification passed four
source/package ownership checks at O0/O3, five parallel-validation programs,
72 Result programs, 133 generic clients, five algebra-Result rejection fixtures,
44 Validation rejection fixtures and 15 accumulation rejection fixtures.
Categories overlap. An initial runner selection named a nonexistent rejection
group; the corrected groups passed without changing fixtures. Reports retained
unchanged inputs and no audit failures. Generated sources, all 48 tooling tests
and strict documentation checks passed.

### Callable ownership lives below algebra

The shared first-argument binder now lives in the callable binding module,
beside native argument-bundle binding. Algebra reexports its existing internal
name. The exclusive borrowed thunk view likewise lives with the other callable
receiver views and keeps its existing algebra import name. Neither owner adds
an algebra dependency to the callable layer.

The implementations and receiver modes are unchanged: consuming the binder
moves its argument, repeating it requires a copyable bound argument, and the
thunk view borrows its original receiver without copying callback state. This
keeps general invocation and ownership rules out of algebra-specific protocols.
Public names, call syntax, exact errors and native origins are unchanged.

All six focused O0 programs passed, including owned Result combination, effect
queries, State origins and native argument capture. Qualification passed four
source/package ownership checks at O0/O3 and the full 726-program checkpoint:
724 test/example checks and two benchmark programs. All 1,621 rejection fixtures
passed. Reports retained unchanged inputs and no audit failures. Generated
sources, all 48 tooling tests and strict documentation checks passed.

### Resource scopes

A scope should own acquisition, use and release as one consumed operation.
Constructing or discarding an unopened scope recipe must not acquire a
resource. Acquisition happens when the scope runs; once it succeeds, release
runs exactly once after use, including when use fails. Nested scopes release
in reverse acquisition order; failure of a later acquisition still releases
every previously acquired resource.

Use the existing callable receiver contracts and Capture/Result conversion
owner for each fallible callback. The new scope runner should own only the
acquired/use/release state transitions. Native destructors cannot report an
arbitrary raised release error, so throwing release belongs in the explicit
scope runner, not in a hidden destructor fallback.

| Outcome | Required result |
|---|---|
| Acquisition fails | Preserve that exact error; do not call use or release. |
| Use and release succeed | Return the owned use result. |
| Use fails, release succeeds | Preserve the use error. |
| Use succeeds, release fails | Preserve the release error and clean the unused use result. |
| Use and release fail | Retain both exact errors in an explicit algebraic outcome, with neither silently replacing the other. |

The existing algebraic-data machinery can represent the combined failure;
its public name and surface syntax remain design decisions. A result or error
borrowing the acquired resource must not escape past release. Test this at the
signature boundary with borrowed spans, not just with runtime counters. Test
all five outcomes, partial acquisition, nesting, move-only callback state,
unused recipes and exactly-once cleanup before designing convenience syntax.

### Fallible source advancement

The current native iterator contract does not raise while advancing. Iterating
`Result` elements is different: an `Err` is an ordinary element and does not
inherently end the source. A fallible source needs an explicit step contract,
conceptually `Result[Optional[T], E]`:

| Step | Meaning |
|---|---|
| `Ok(Some(value))` | Yield one value. |
| `Ok(None)` | Exhaustion; enter the terminal state. |
| `Err(error)` | Yield the exact advancement failure once; enter the terminal state. |

Further steps after exhaustion or failure must not pull the underlying source.
A move-only error is transferred once. Converting a sequence of Result elements
into this terminating behavior must be explicit. Preserve the existing
infallible iterator protocol and share normalization, callback invocation and
consuming terminal drivers where their contracts apply; one fallible step
owner should handle the additional terminal/error state.

A fallible map requires a repeatable callback, preserves source order, and
stops without another pull when either advancement or mapping fails. Distinct
source and callback errors need an explicit common mapping or algebraic error
sum. Early folds, abandoned adapters and resource-backed sources must release
owned state exactly once. Qualification must distinguish source failure from
stored element errors and verify no read-ahead, no eager buffering introduced
by error handling, exact borrowed origins, and cleanup on every terminal path.

## Release readiness

The current Linux checks qualify the stated contracts, not arbitrary native
callback shapes. The compatibility inventory keeps the functional checkpoint,
installation evidence and historical baseline separate. Compilation measurements
are observations with exact inputs, flags and budgets.

`NativeUnary.function` changed from a public field to `function()` and
`into_function()`. That approved source incompatibility means the next stable
release should use a new major version under semantic versioning. The present
work does not change a release number, create a tag or publish a registry
package. A release pass should choose that version explicitly, retain the Mojo
1.2 pin, publish migration notes, and qualify any additional claimed platforms.
