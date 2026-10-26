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

## Further migration

Every legacy Piped method now has a selected counterpart in the inventory.
Equal method names do not imply equal capability coverage: intrinsically
Result-specific operations remain classified separately, and extension
contracts still matter for custom dictionaries and deferred families.

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

The designs below are not implemented public APIs. They add distinct
ownership or source-advancement contracts, rather than more overloads to the
current admission table. Prototype them independently, qualify normal and
invalid user calls at O0/O3 through source and packages, then promote one
complete contract at a time.

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
