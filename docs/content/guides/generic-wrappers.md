# Generic wrappers

Ordinary calls use `pipeline(value)` and its operations. Public operation
contracts become useful when you write a reusable function over a family and
library callback types. They describe the proof, result and native error that
your wrapper forwards to an existing operation.

A wrapper usually needs three projections: an admission predicate in `where`,
`Out` as its return type, and `Error` as its raised type. If it returns a fluent
`Pipeline`, it also projects `Family`. The contract introduces no stored value
or additional execution step.

## Forward one operation contract

This maintained example shows both patterns. `mapped` checks a unary receiver
through `MapContract.InvocationCompatible`. `gather` forwards the source and
target traversal rules through `TraverseContract.Compatible`. The ordinary
call sites infer the callback and carrier types.

<!-- example: docs/examples/operation_contracts.mojo -->

The family remains a generic parameter such as `I: Functor`. Carry the complete
source type as `V`; rebuilding it from its element type can lose native origins
or a deferred representation. Pass owned values onward with `^` at the existing
consuming boundary.

## Choose the admission proof

| Projection | What it establishes |
|---|---|
| `Compatible` | The documented operation's admission. Its exact requirements depend on the operation. Existing wrappers can keep this proof. |
| `ReceiverCompatible` | The documented receiver requirement. Some contracts require a repeatable callback; others check whether a single invocation is available. |
| `InvocationCompatible`, where provided | `Compatible` plus the documented receiver requirement for a new wrapper boundary. Missing receiver methods fail at that boundary. |
| Component predicates | Individual input, carrier, output, error or family requirements. Forward the components documented for that particular contract. |

Use `InvocationCompatible` for a new wrapper when its descriptor offers it.
Map, bind, combination, sequencing, conditional composition, validation, outcome
handling, stored-error mapping and staged folding expose this optional stronger
proof. FoldContract requires a repeatable binary receiver for staged invocation. Some
contracts already include their receiver requirement in `Compatible`, including
`ApContract`, `FoldMapContract` and `FindMapContract`.

Receiver availability does not make a consuming callback repeatable or make its
captures copyable. A branching or multi-element family retains those additional
requirements. For example, accepting a callback once for a single optional value
does not establish that the same callback can visit every element of a list.

Existing combined and expanded proofs remain supported. On Mojo 1.2, moving an
expression into a different Boolean alias can affect symbolic overload inference
even when concrete truth values agree. Use the documented contract or components
instead of reconstructing its private adapters or strengthening an old wrapper's
proof incidentally.

## Choose the descriptor

Most descriptors are exported from `fp.algebra`. The two redemption descriptors
are exported from `fp.functions`.

| Operation | Public descriptor |
|---|---|
| Map or dependent bind | `MapContract`, `BindContract` |
| Lazy combination, evaluated combination or pairing | `CombineContract`, `Map2Contract`, `ProductContract` |
| Apply stored callbacks | `ApContract` |
| Traverse into another family | `TraverseContract` |
| Filter or map to optional values | `FilterContract`, `FilterMapContract` |
| Retain, pair or discard a value around an effect | `FlatTapContract`, `FlatPairWithContract`, `BeforeContract`, `FollowedByContract` |
| Choose an effectful branch | `IfContract` |
| Validate a success or observe a whole stored outcome | `EnsureContract`, `AttemptTapContract` |
| Handle either original outcome | `RedeemContract`, `RedeemWithContract` |
| Map stored errors or both payloads | `MapErrContract`, `MapBothContract` |
| Recover a stored error to a value | `RecoverContract` |
| Recover matching errors to a value or another carrier | `RecoverIfContract`, `OrElseIfContract` |
| Observe a stored error directly or through an effect | `TapErrContract`, `FlatTapErrContract` |
| Fold, accumulate mapped values or search | `FoldContract`, `FoldMapContract`, `FindContract`, `FindMapContract`, `AnyContract`, `AllContract` |

See the [algebra reference](../reference/algebra.md) and
[function reference](../reference/functions.md) for each descriptor's parameters
and component predicates. Do not assume every descriptor has the same fields
or admits the same source representations.

## Forward recovery and error observation

Recovery descriptors already include receiver admission in `Compatible`.
This maintained wrapper uses one signature for an immediate Result and a
deferred ResultT/Reader action. The call sites supply only the family; carrier
and handler types are inferred.

<!-- example: docs/examples/recovery_contract.mojo -->

Use `RecoverIfContract` for a replacement value and `OrElseIfContract` for a
replacement carrier when a predicate selects which errors to handle. Use
`TapErrContract` or `FlatTapErrContract` when the error should remain in the
output after observation. These contracts describe the selected stored-error
layer; they do not catch arbitrary native raised errors.

Keep the same family witness in the contract and operation call. Value recovery
through a conditional `ApplicativeError` capability needs its public downcast
witness in both places. `TapErrContract` can use the original `Functor` directly,
including mapping-only families. The [algebra reference](../reference/algebra.md)
describes these distinct capability requirements and component predicates.

## Preserve family, error and ownership

When returning a selected pipeline, project the descriptor's `Family` and
`Out` together. An operation can change the continuation family: filtering a
nonempty collection can produce an empty list, and mapping a Result's stored
error can select a different Result error family. A custom dictionary retains
its own selection rules even when its carrier happens to be a native Result.

`Error` describes construction of `Out`. A Reader or State recipe can construct
without raising and retain a callback error until `run`. Forward the resulting
action's run contract at that later boundary; declaring a wrapper non-raising
does not establish that the deferred computation cannot fail. Stored Result
errors and native raised errors remain distinct channels.

Payload and error equalities include their origins. Forward the existing
`Out` and `Error` types directly, including borrowed views. An owner must outlive
the returned view or deferred computation. The contract does not copy a moved
capture, extend a lifetime, or convert one native error type into another.

## Forward a shared callback

Use `shared_ref(callback)` when a generic wrapper borrows a shared library
callable and forwards it to an operation that owns its callback. No capture
copy is required. For example, a wrapper accepting `F: Thunk` can return
`Result[F.Out, F.Error]` from `attempt_once(shared_ref(factory))`.

For operation descriptors, spell the callback as the public `SharedRef[F, o]`,
where the wrapper accepts `ref[o] factory: F`. A sequencing wrapper then uses
`BeforeContract[I, V, SharedRef[F, o]]` for its admission, output and error,
and calls `pipeline[I](source^).before(shared_ref(factory)).get()`.
Use the same explicit reference in both the descriptor and the operation:
deferred output types retain the actual callback representation and origin.

The reference supports every shared call shape of the original and always
selects shared invocation. Mutable-only and consuming-only callbacks require
their existing receiver boundaries. `mut_ref(callback)` remains the choice
when the wrapper should mutate and retain caller-owned state.

## Native callbacks and diagnostics

These descriptors describe library callable protocols. Native callbacks retain
their ordinary signature-inference boundaries. Use the documented native
operation overload or an existing callable adapter; a contract does not infer
an arbitrary native function's argument conventions.

A violated-constraint diagnostic identifies the rejected wrapper boundary.
Check its component predicates for input identity, family carrier membership,
output policy, native error compatibility and receiver availability. If those
pass but a deferred `run` fails to compile,
inspect the action's run requirements and the actual environment or state
origin. The [troubleshooting guide](troubleshooting.md) covers the retained
compiler-specific limits.
