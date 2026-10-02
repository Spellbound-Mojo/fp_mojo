# Architecture overview

FP Mojo is a functional-programming library for Mojo. It adds
composition, partial application, folds and lazy adapters, typed success and
failure values, algebraic data types with exhaustive pattern matching, functional control flow and a small algebra of Functor/Applicative/Monad instances with effect transformers.

We have no intention of designing another language on top of Mojo. That is why the library supplies only the behavior that Mojo 1.1 does not already provide; see [design principles](principles.md).

## Packages

Each public package has an `__init__.mojo` that re-exports its supported names
and contains nothing else. The package root `fp` has no re-exports: import from
the package that owns a name, for example `from fp.data import Result`.

| Package | Responsibility | Modules |
|---|---|---|
| `fp.callables` | Fixed-arity callable protocols, borrowed endpoints, receiver dispatch and native functions as library values (`as_unary`) | `protocols`, `invoke`, `native`, `products`, `_receiver` |
| `fp.functions` | Immediate pipelines, returned composition, argument flipping and partial application | `pipeline`, `_stages`, `composition`, `flipped`, `partial` |
| `fp.iteration` | Lazy adapters, scans, folds, reductions and predicate terminals over native iterators and owned collections | `adapters`, `folds`, `_terminal`, `_advance`, `_callbacks` |
| `fp.control` | Functional `while_loop`, `fori_loop` and carry/output `scan` | `loops`, `scan`, `_loops` |
| `fp.adt` | Algebraic data declarations and their values: shared `Node`s and `Choice`s stored in place (`Data`, `Cases`, `Node`, `Choice`) | `data` |
| `fp.data` | `Result`, `ControlFlow` and native-error bridges | `_result`, `result`, `control` |
| `fp.algebra` | Functor, Applicative, Monad, Traversable and Monoid interfaces with native instances | `protocols`, `operations`, `instances`, `_derived`, `monoids` |
| `fp.effects` | Reader, State and Writer computations and the OptionalT, ResultT, ReaderT, StateT and WriterT transformers | `protocols`, `reader`, `state`, `writer`, `layers`, `operations`, `_adapt` |
| `fp.matching` | `match` over data values, `Optional` and tuples, `rewrite` over `Node` values, `when` guards and `Next` | `matcher`, `clauses`, `_engine`, `_inline` |

`fp._internal` is private. It holds exact error admission and propagation
(`errors`). Helpers that belong to one domain stay in that domain's package:
iterator step bridges live in `fp.iteration`.

In matching, `matcher` holds the public entry points and their generated
overloads; `_engine` owns clause sets, admission and the loop that matches one
`Node`; `_inline` matches any other subject, and several subjects, with the
same clause sets; `clauses` holds `Next`, `Guarded` and `when`.

## Layers and dependency direction

For convenience, we show the dependencies between modules:

```text
Layer  Modules                         Builds on
  0    Mojo language and std           —
  1    fp._internal                    Mojo
       fp.adt (Data, Node, Choice)     Mojo
  2    fp.callables                    _internal
  3    fp.functions                    callables
       fp.data (Result, ControlFlow)   callables, adt
       fp.matching                     adt, _internal
  6    fp.iteration                    callables, data.control
  7    fp.control                      iteration, adt
       fp.algebra                      data, functions (Identity), iteration
  8    fp.effects                      algebra, data
       data.result (integration)       algebra (collect_results)
```

Some packages import each other at different modules: the Result carrier (`data._result`) sits below algebra, and the public `data.result` module adapts `collect_results` to the algebra
collection kernel above it. We have rules that keep the graph acyclic are:

- `adt.data` depends only on Mojo itself. `Result` and `ControlFlow` build on
  it, and can be used without importing any matching machinery.
- Function application is independent of matching.
- Matching builds on `adt.data` and the error helpers, and on nothing else in
  the library; it recognizes `Result` and `ControlFlow` through the data core.
- Algebra does not import effects. Transformer dictionaries supply concrete
  deferred operations to algebra through its operation descriptors instead.
- Package initializers contain only re-exports; private package initializers
  are empty.

## Shared mechanisms

Each concept has one implementation at the lowest layer that can own it.
Higher packages compose that implementation and add only their own behavior.

| Mechanism | Owner | Consumers |
|---|---|---|
| Exact error compatibility, native error propagation and a callback's normalized error (`_NativeError`, `_forward`) | `_internal.errors` | Invocation, Result folds, match clauses and `when` |
| Declared data: constructors, recursive positions, stored values and their release | `adt.data` (`Data`, `Cases`, `Node`, `Choice`) | Matching, rewriting, `Result`, `ControlFlow`, user code |
| Clause sets, admission and the loop that matches a `Node` | `matching._engine` | `match` on a `Node`, with or without a context, and `rewrite`; the matcher for other subjects reuses its clause sets and calls |
| Subjects that are not Nodes: their cases, the clause argument for each, and admission | `matching._inline` | `match` on a `Choice`, `Result`, `ControlFlow`, `Optional` or other value, and on several values |
| Fixed-arity callback invocation mode | `Unary`/`Binary`/`Thunk` with `call_once` and `call_repeated`; error-adapting helpers in `callables._receiver` | Algebra instances, deferred effects, traversal, iteration and control callbacks, Result transformations, compositions |
| Sequential consuming terminal loop | `iteration._terminal` with `data.ControlFlow` and `iteration._advance` | Folds, reductions, `collect_list`, `find`, `any`, `all` |
| Iteration sources (an iterator as it is, or a consumed owned collection) | `iteration._advance` (`_Source`, `_source`) | Every public iteration entry point, and `flatten` for inner values |
| Native functions as library values | `callables.native` (`NativeUnary` through `as_unary`, `_NativeUnaryRef`, `_ThinFunction`, `_NativeBorrow`, one native call in `_call_native`) | Pipelines and compositions, algebra and effect callbacks, Result methods |
| Result transformations | `data._result` (`_transform_result_owned` and the four methods) | `ResultFamily.map` and `flat_map`, generic Result code |
| Algebra operations and their result types | `algebra.protocols` (static methods and associated aliases) | Native and third-party instances, transformers |
| Runtime-sized owned traversal | `algebra.protocols._loop` with an accumulation policy (`_Accumulate`) | `collect`; one loop per family; OptionalT, ResultT and WriterT wrap the policy and delegate to their base |
| Choice between two carriers of one family | `Monad._Joined`, `_join_left`, `_join_right` | OptionalT/ResultT bind and map2 steps, Writer, Reader and State choices |
| Lazy right operand, produced once | `algebra.protocols._Lazy` | State, OptionalT and ResultT map2 steps |
| Owned pair split | `callables.products` (`_take_pair`) | State and Writer steps, `scan` |

Borrowed and owned results stay separate because Mojo gives them different
contracts. Flattening owns an outer/inner state machine; scans own an initial-snapshot
phase. Merging these into one erased callback or an unconstrained origin
conversion would hide the rules their correctness depends on.

## Explanation of behaviors

Every public operation's semantics are stated in its [API reference](../reference/index.md)
chapter. The architecture chapters explain why each package is shaped the way
it is:

- [Callables and invocation](callables.md): the call boundary every
  higher-order operation shares.
- [Functions and partial application](functions.md): pipelines, composition,
  `flip` and `partial`.
- [Iteration](iteration.md): lazy adapters, folds and the terminal driver.
- [Result, Optional and ControlFlow](data.md): typed outcomes and error bridges.
- [Algebraic data and matching](matching.md): declared data, shared and
  in-place values, and matching.
- [Algebra and effects](algebra.md).
- [Laws](laws.md), [performance](performance.md),
  [native Mojo boundaries](native-boundaries.md) and
  [verification](verification.md).
