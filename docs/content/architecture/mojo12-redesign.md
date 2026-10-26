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
| Native errors stored as Result | `data._result._attempt_core`, `attempt_once` | Bind a consumed argument bundle through `_BoundThunk`; never duplicate catching logic. |
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

## Native signatures and storage

`generate_context.py` and `generate_capture.py` share
`scripts/native_signatures.py`. Known consumed operands use `_NativeOwnedArg`;
read operands and results retain explicit register or memory evidence.
`generate_native_conventions.py` emits the existing binary, keyword and mutable
invocation bodies from the same descriptor. Generated files are checked against
their generators by the tooling suite.

Native closures keep an origin-preserving reference view. Deferred operations
own plain thin pointers through the existing inline optional cell. This avoids
losing native witnesses in generic fields without allocating callable boxes or
copying captures. Capture argument bundles contain native pointers for borrows
and owned fields for consumed operands and keyword dictionaries. Invoking a
bundle consumes its receiver, so native cleanup handles partially moved fields
when the call raises.

Literal no-value returns and `raises Never` have explicit invocation paths.
Capture also needs a literal Never admission specialization to resolve the
read/read tie with a selected-error closure signature. Stateful factories keep
a borrowed-pointer fallback for symbolic signatures, while exact register
variants take priority for concrete functions. The stateful owner still copies
the pointer into its own cell; reassigning the caller's pointer cannot change it.

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

The next designs below are not implemented public APIs. They add distinct
ownership or source-advancement contracts, rather than more overloads to the
current admission table. Prototype them independently, qualify normal and
invalid user calls at O0/O3 through source and packages, then promote one
complete contract at a time. No CI work is part of this sequence.

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
