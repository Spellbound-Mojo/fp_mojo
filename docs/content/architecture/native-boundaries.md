# Native Mojo boundaries

The library is pinned to Mojo 1.1.0. This page lists the Mojo 1.1 behaviors
that shape the library's design, the workaround for each, and the compiler change
that would let the library drop it.

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
| Keyword packs are homogeneous, cannot be forwarded into named parameters, and parameter names are not reflected. | No keyword binding in `partial`. A call needing keywords or defaults is written as a closure. `attempt` forwards only native `**kwargs: K` packs. | Heterogeneous keyword packs forwarded into named parameters, or signature reflection. |
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
reproduced the closure-return and pack limitations above. The project remains
pinned to 1.1.0.
