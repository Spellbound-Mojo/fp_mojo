# Callables and invocation

`fp.callables` defines the invocation protocols shared by pipelines, folds,
Result transformations and other higher-order operations. A protocol specifies
the callable's arguments, result, error type and receiver access, so consumers
can use the same invocation rules.

Match clauses use native thin function signatures directly. They accept plain
functions and lambdas without captures; see
[algebraic data and matching](matching.md).

## Callers of two kinds

A higher-order function receives user code in one of two forms:

| Form | Examples | How it is called |
|---|---|---|
| **Native function or closure** | `def f(x: Int) -> Int`, a capturing `def` | Directly, through a function-typed parameter of the entry point |
| **Library callable value** | `Partial`, `Composition`, `Flipped`, `NativeUnary`, user structs | Through a fixed-arity protocol (`Unary`, `Binary`, `Thunk`) or `BorrowCallable` |

A native function with keyword or default
parameters is used through a closure that spells the call.

## Three independent dimensions

Receiver access, argument conventions and result ownership are independent:

- **Receiver access.** Shared (the callable is read), exclusive (mutated in
  place) or consuming (called once and destroyed). Owning captured state does
  not make a callable single-use, and shared access is not a purity guarantee:
  a native closure can have effects through its captures.
- **Argument conventions.** Each argument is read, mutable or owned on its own.
  A shared callable may consume its arguments; a consuming callable may borrow
  them. No automatic copy makes an invalid combination compile.
- **Result.** An owned value, or an explicitly origin-bound reference. The native
  error channel stays separate from any `Result` value that is returned.

An algorithm requires only the receiver access it actually uses. A repeating
algorithm keeps one receiver for its whole run and never copies it per call, so
a consuming-only callable is rejected at compile time wherever a callback runs
more than once.

## Fixed-arity protocols

`UnaryContract`, `BinaryContract` and `ThunkContract` fix the argument, result
and error types on the callable itself. Each receiver mode is a separate trait:

| Arity | Shared | Exclusive | Consuming |
|---|---|---|---|
| one owned argument | `Unary.call` | `MutableUnary.call_mut` | `OnceUnary.call_once` |
| two owned arguments | `Binary.call` | `MutableBinary.call_mut` | `OnceBinary.call_once` |
| no argument | `Thunk.call` | `MutableThunk.call_mut` | `OnceThunk.call_once` |
| one borrowed argument | `BorrowCallable.invoke` | `BorrowMutableCallable.invoke_mut` | `BorrowOnceCallable.invoke_once` |

A type implements only the modes it supports. Two free functions choose the mode:

- `call_once(f, ...)` calls any mode once and prefers the consuming one.
- `call_repeated(f, ...)` calls a callback that stays usable and prefers
  exclusive access. Generic code asserts `RepeatableUnary[F]`,
  `RepeatableBinary[F]` or `RepeatableThunk[F]` first, which is how a
  consuming-only callback is rejected before anything runs.

Borrowing callbacks use `RepeatableBorrow` and
`invoke_borrowed_repeated[E](payload, callback)` for the same exclusive-first
receiver choice. The payload remains borrowed independently of receiver
mutation. The public contract and invocation owner replace the former private
mutable-borrow trait and dispatcher; their private import names remain aliases
for existing internal consumers. There is one receiver and error policy.

Lazy iterator predicate owners and consuming searches both use
`iteration._callbacks._predicate_repeated`, which retains exclusive access to
the stored callback through a typed pointer. Filtering, prefixes and branch
routing keep their existing drivers; searches keep `_find` and `_quantify`.
Counting uses the existing borrowed-to-owned unary adapter and accumulation
policy. Owned search admission derives the element directly from the source,
so ordinary and generic callers do not select a separate element parameter.

Extrema and lazy iterator observation use `_ObserveOnce`'s existing
repeatable receiver, guarded by `RepeatableBorrow` at admission. Its
`call_mut` borrows a payload through the canonical borrowing dispatcher,
then `_observed` retains that payload beside the projection or discards the
projection. `_extremum` still delegates to `_map_accumulate` and `_Choose`:
keys are computed once and strict comparison retains the first tie. No
observer loop, receiver policy, or cleanup path is duplicated.

Family observation retains `_Observe` as its adapter type, preserving existing
generic `Family.Mapped` and `Family.MapError` signatures. It exposes a shared
receiver when the callback is shared and a mutable receiver when it is
repeatable. Mojo 1.2 requires their common `UnaryContract`, `Movable`, and
`Deinitable` ancestors explicitly because these conformances have different
conditions. Both `_Observe` and `_ObserveOnce` delegate repeated execution
to `_observe_repeated`; `_observed` remains the payload-retention owner.
Whole-value owned `tap` selects `_ObserveOnce` and its consuming-first policy.
Per-element family observers retain their repeatability requirement, even
when a particular carrier contains at most one element. Deferred family
mapping still owns timing, callback storage, and error delivery.

`as_unary(f)` moves a native function or closure into a `NativeUnary`, a `Unary`. `Partial`
implements `Thunk`, `Unary` or `Binary` when zero, one or two arguments remain;
`Composition` has the arity of its first-applied stage; `Flipped` is a `Binary`.
The Mojo 1.1 O3 measurements matched direct function calls. That performance
result has not been requalified for Mojo 1.2.

The types live on the callable, so an algebra instance, an effect or a
composition computes its result type from the callback's `Out` alias without any
binding plan. Deriving types through per-call metadata instead is what made
programs take minutes to compile (see
[algebra and effects](algebra.md#why-the-core-is-shaped-this-way)).

## Native functions and closures

On the Mojo 1.2 nightly branch, `NativeUnary` stores its callback in the same
inline optional cell used by composition. Direct generic fields lose native
function witnesses on this compiler. The cell remains occupied until the
wrapper is consumed; construction and calls neither allocate nor copy captures.
Conditional copyability and the callback's embedded origins are retained.

The public `function` field is now a borrowing `function()` method. Use
`wrapped.function()` to access the native callback and
`wrapped^.into_function()` to extract it. `as_unary`, direct construction,
`call` and `__call__` keep their existing calling forms. Lazy iterator adapters
use the same storage representation and retain mutable access between pulls.


`as_binary` exposes the existing owned binary adapter as `NativeBinary`; the
private `_NativeBinary` name is an alias so existing signature spellings remain
stable. Its optional cell and `_call_native_binary` invocation are unchanged.
The public adapter adds the same borrowing and consuming function accessors as
`NativeUnary`, direct calls, and conditional implicit copyability. The standard
`_BinaryViewable` marker admits shared receiver views in binary iteration
operations without broadening that admission to custom dual-receiver callables.

Both pointer factories use `native_factories` and one declaration renderer.
The binary factory spells the two owned operands and their native ABI variants;
it admits plain declarations and stored thin pointers without function-trait
overload inference. The current factory does not infer captured closures.
Pointer admission copies the pointer, never invokes it, and retains no borrow
of its source variable.

`BinarySignature[A, B, R, E].capture` selects the entire signature before
admitting a closure. The selected type supplies every input, result and error;
only the callback's concrete `F` is inferred at the static method boundary.
Six generated admission forms distinguish pure, literal `raises Never` and
typed raising callbacks, each with value/no-value signatures. They reuse `_Binary` and `_RaisingBinary` for value signatures and
spell native no-value traits literally. Each delegates storage to `NativeBinary`.
There is no new invocation, error handling, receiver policy or capture copy.
Plain declarations retain Mojo's contextual conversions: for example, selecting
`NoneType` can materialize an explicit unit result from a no-return declaration.

Selecting types in the receiver avoids overload inference of those types from
an incompatible callback. The rejection fixtures exercise mutable arguments,
wrong input/result/error types, wrong arity and noncallables without an explicit
`F` binding. The normal `as_binary` factory keeps its thin-only admission;
existing explicitly typed `NativeBinary` construction also remains available.

`BorrowSignature[A, R, E].capture` applies the same selected-signature policy
for a read-only payload. Both selectors share the closure admission generator.
`NativeBorrow` exposes the existing `_NativeBorrow` owner, retained as an alias,
and adds `_BorrowViewable` shared views and native-function accessors. Its
optional cell and `_call_native_borrow` remain the sole storage and invocation
owners. Capturing never invokes the callback, copies owned captures or owns
the inspected payload. Returned borrowed origins remain native origins.

Thin pointers use the existing `variants` ABI descriptors. Admission infers
only the complete pointer type `F`, then compares it to a signature whose
input and result ABI parameters default from the selected `A` and `R`.
This preserves aliased pointers: matching a borrowed pointer against a spelled
function argument loses aliases on Mojo 1.2. Fresh trait-bounded parameters
retain register evidence that is lost when a projection is embedded directly
inside a function type. The alternatives explicitly partition the selected
ABIs; a default `downcast` alone does not make an incompatible candidate
nonviable. Literal `raises Never` and literal no-return signatures stay distinct.
These boundaries only copy an admitted pointer into the existing owner.

Mojo 1.1 records a native function's signature only when the value passes
through a parameter of that exact function type (`F: def(A) -> R`); a plain
generic `F` loses it. Each entry point that accepts closures therefore has one
overload per supported arity. A non-raising closure also does not match
`def(A) raises E -> R` with `E` inferred, so non-raising and raising closures have
separate overloads, and a raising callback keeps its exact error type.

Plain functions (no captures) convert to further signature shapes at a call
site, which the library uses where closures cannot reach:

- `partial` and `flip` accept plain functions of any arity through a read
  argument pack, because each call site forwards the pack unchanged.
- `pipe`, `flow` and `compose` accept two to eight plain functions through one
  overload per stage count, each stage spelled as a thin signature whose error
  is inferred (`Never` for a non-raising function). A variadic pack keeps a plain
  function's type but not its signature, so a stage's result could not be
  inferred from it. Each function is stored as a `_ThinFunction`, a `Thunk`,
  `Unary` or `Binary` value, and the chain goes through the ordinary planner.
- Two-stage mixed `flow` and `compose` use the same spelled native signature
  boundary beside one library stage. The `native_factories` descriptor also
  drives `as_unary` and `as_binary` pointer admission: it owns pure/raising and literal
  no-value signatures, obtains register/memory evidence and the symbolic
  fallback from `factory_pointer`, and uses `native_adapter` to select
  the existing owner. The overload constructs `Composition`, whose constructor
  performs the same capability, arity, type and error checks as library-only
  composition. There is no additional plan, storage or invocation mechanism.
  Consumers retain their own library-stage bounds and parameter order around
  that descriptor. Existing consumers preserve their public signature spellings and overload
  order.
- Inferred two-stage mixed `pipe` uses that factory descriptor to normalize
  one native unary stage and borrows the other through `Unary`. It forwards
  both to the original immediate pipeline. The existing plan, stage checks
  and `_ImmediateRunner` still own execution, errors and payload cleanup.
  This admission does not store or consume the library stage, and retains
  the existing explicit error/result bindings through their original overloads.
- Match clauses are plain functions and lambdas without captures, through one
  generated overload per clause count; each clause's signature is read at a
  parameter of its own function type.

## Borrowed calls

`BorrowCallable` and `BorrowOnceCallable` are the fixed-metadata forms for read
access: `Payload`, `Result` and `Failure` are exact native types shared through
`BorrowCallContract`. `invoke_borrowed` calls a `BorrowCallable` with a borrowed
payload; iterator predicates, `while_loop` predicates and Result folds use this
route. The library never asserts two origins equal or rebinds a result to a
different origin to make a call compile.

## Shared callback views

Callback storage and receiver invocation have separate owners. An operation
with shared admission borrows a supported standard callback and stores its
origin-indexed view. The view has the fixed callable protocol expected by the
existing operation; it introduces no dispatch loop, capture copy or allocation.
An explicit move continues through the operation's owned callback overload.

| Operand contract | Admission | Retained receiver |
|---|---|---|
| One owned operand | `_UnaryViewable._View[o]` | `_SharedUnaryRef` for a fixed-output Unary, or Kleisli's origin-indexed view |
| One borrowed operand | `_BorrowViewable._BorrowView[o]` | `_SharedBorrowRef` for a BorrowCallable |
| Two owned operands | `_BinaryViewable` | `_SharedBinaryRef` for a fixed-output Binary |

Unary Partial, NativeUnary and ordinary Composition use the fixed-output view.
A unary ordinary composition exposes shared admission only when all its stages
support shared calls. Kleisli uses its planner's shared view because an
effectful result can depend on the callback receiver's origin;
`_UnaryViewable` therefore extends
`UnaryContract`, not `Unary`. A unary Partial also provides the borrowed-input
view, forwarding both protocols to its one native call owner. Its prefix-copy
semantics remain part of invocation rather than admission.

The common syntax descriptor selects the correct view, associated input,
result and error types. Individual operation generators retain family policy,
parameter positions and native signature evidence. They forward to the same
mapping, filtering, accumulation, recovery and iterator owners used by owned
callbacks. Admission of an ordinary library Unary or BorrowCallable does not
implicitly grant this private standard-callback adaptation.

Binary Partial, shared binary Composition and the shared binary forms of
Flipped and FlippedFunction opt into `_BinaryViewable`. This marker needs no
output projection: Binary already fixes both operands, output and error.
The same shared descriptor constructs `_SharedBinaryRef` for indexed mapping
and zipping, and for carry/output scans. Handwritten snapshot-scan admission
constructs the same view and delegates to its original owner.
Opting in only standard wrappers preserves custom callables:
a custom implicit-copy value implementing Binary and MutableBinary must keep
the owned overload's preference for `call_mut`. A general borrowed Binary
overload would silently choose its shared `call` instead.

Views carry the exact callback origin through iterators, independent branch
handles and deferred effects. Output origins are preserved independently:
an output borrowing an external owner need not borrow a local callback, while
an output that retains a receiver borrow keeps that receiver alive. The library
never extends a lifetime or copies a captured owner to make reuse compile.
The [user guide](../start/ownership.md#reuse-callbacks-by-name) explains these
choices without requiring the internal view types.

## How consumers use the call boundary

| Consumer | Route and receiver |
|---|---|
| `pipe`, `flow`, `compose` | Plain functions stored as thin functions, closures promoted with `as_unary`, and `Thunk`/`Unary`/`Binary` values; the planner infers each stage's types |
| `piped(...).then` | One native function, closure or `Unary` value per call, inferred at that call |
| `flip` | A `Binary` value (receiver modes kept) or a plain function through a read pack |
| `partial` | A plain function stored directly; the result implements `Thunk`/`Unary`/`Binary` |
| `map`, `filter_map`, `flat_map`, `scan_left`, folds, reductions | Native callbacks or the operation's unary/binary protocol; owned callbacks and supported shared views use the same driver |
| `filter`, `find`, `any`, `all` | Native predicates or `BorrowCallable`; candidates are borrowed |
| `attempt`, `attempt_kwargs`, `attempt_once` | Native calls or a `OnceThunk`, then the Result bridge in `fp.data` |
| Result methods and folds | Native, fixed-arity or borrowed callbacks, called on the stored case |
| `fp.match`, `fp.rewrite`, `fp.when` | Plain functions and lambdas without captures, called through their native thin function type |
| `while_loop`, `fori_loop`, `scan` | Native callbacks, shared-receiver `Unary`/`Binary`, `BorrowCallable` predicates |
| `fp.algebra`, `fp.effects` | Fixed arity with `call_once` and `call_repeated`; native callbacks enter `map`, `flat_map` and `traverse` as a borrowed `_NativeUnaryRef` (held by a deferred computation until it runs) and `modify`, `censor` and `local` as a moved `NativeUnary` |

Domain algorithms stay with their owners: matching keeps clause selection and
its loop; iteration keeps its loops and state machines; `fp.data` owns the
conversion from a raised error to a `Result`. `fp.callables` adds no runtime
registry, dynamic dictionary, lifetime system, raw pack layout or origin
conversion.
