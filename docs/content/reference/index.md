# API reference

This reference covers every public name of FP Mojo on Mojo 1.1.0. Each package
page opens with a short note on when you need the package, then the reference
generated from the source's docstrings: the package's shared contracts
(ownership, evaluation order, laziness, errors, empty and no-match behavior,
costs), a summary table, and every public name with its signature, parameters,
arguments, result and error. Most pages end with runnable examples.
To learn the library from the start, follow the [tutorial](../tutorial/pipelines.md).

## Packages

| Package | Contents |
|---|---|
| [`fp.callables`](callables.md) | Callable protocols, receiver modes and `as_unary` |
| [`fp.functions`](functions.md) | Pipelines, composition, `flip` and partial application |
| [`fp.iteration`](iteration.md) | Lazy adapters, folds, reductions and searches |
| [`fp.control`](control-flow.md) | `while_loop`, `fori_loop` and carry/output `scan` |
| [`fp.adt`](adt.md) | Data declarations and their values: `Data`, `Cases`, `Node`, `Choice` |
| [`fp.data`](data.md) | `Result`, `ControlFlow` and the bridges between raised and stored errors |
| [`fp.algebra`](algebra.md) | Functor, Applicative, Monad, Traversable and Monoid, with native instances |
| [`fp.effects`](effects.md) | Reader, State and Writer, and their transformers |
| [`fp.matching`](matching.md) | `match`, `rewrite`, `when` guards and `Next` |

Import each name from its package, for example `from fp.iteration import
fold_left`. The package root `fp` re-exports `match`, `rewrite` and `when`, so
that `import fp` is enough to write `fp.match(...)`.

## Read a declaration

- Square brackets hold compile-time parameters. `//` separates parameters that
  are inferred from those you supply explicitly.
- `Self.X` names a type's associated alias. `where` clauses are part of the
  signature: a call that does not satisfy them does not compile.
- `var`, `ref`, `mut`, `deinit` and `raises E` have their Mojo meanings,
  summarized in [ownership and errors](../start/ownership.md).
- Some factories return private descriptor types. Build those values with the
  public factory; never construct a private descriptor directly.
- Each declaration links to the exact source file it comes from, including all
  overloads.

## Common preconditions

- Owners must outlive every reference derived from them.
- `Node` values are finite and acyclic by construction, and `Choice` values
  hold no children; no precondition applies.
- Algebraic laws assume pure, terminating callbacks; the library does not
  enforce purity.

Known compiler limitations that affect particular callback forms are listed in
[support and limitations](../guides/status.md).
