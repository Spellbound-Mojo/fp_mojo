# API reference

This reference covers every public name of FP Mojo on Mojo 1.1.0. Each package
page is generated from the source's docstrings: the package's shared contracts
(ownership, evaluation order, laziness, errors, empty and no-match behavior,
costs), a summary table, then every public name with its signature,
parameters, arguments, result and error.

## Packages

| Package | Chapters |
|---|---|
| `fp.callables` | [Callables and invocation](callables.md) |
| `fp.functions` | [Pipelines, composition and partial application](functions.md) |
| `fp.iteration` | [Lazy adapters, folds and terminals](iteration.md) |
| `fp.control` | [Functional control flow](control-flow.md) |
| `fp.adt` | [Data and values](adt.md) |
| `fp.data` | [Result, ControlFlow and error bridges](data.md) |
| `fp.algebra` | [Interfaces and native instances](algebra.md) |
| `fp.effects` | [Reader, State, Writer and transformers](effects.md) |
| `fp.matching` | [Matching and rewriting](matching.md) |

Import each name from its package, for example `from fp.iteration import
fold_left`. The package root `fp` re-exports `match`, `rewrite` and `when`, so
that `import fp` is enough to write `fp.match(...)`.

## Reading a declaration

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
