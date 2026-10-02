# Sources and attribution

The library borrows ideas, not code, from the projects below. Each entry says
what was adopted and what deliberately was not. No source code has been copied
from any of them; the only runtime dependencies are Mojo and its standard
library.

## Design references

| Source | Adopted | Not adopted |
|---|---|---|
| [Lean 4: inductive types](https://lean-lang.org/doc/reference/latest/The-Type-System/Inductive-Types/) and [pattern matching](https://lean-lang.org/doc/reference/latest/Terms/Pattern-Matching/) | Constructor descriptions, eliminators, the distinction between case analysis and recursive folds, typed case structure | Dependent motives, positivity checking, proofs, checked termination |
| [Lean 4: functors and monads](https://lean-lang.org/doc/reference/latest/Functors___-Monads-and--do--Notation/) | Separating an available operation from evidence that it is lawful | `do` notation |
| [Coconut](https://coconut.readthedocs.io/en/latest/DOCS.html) | Constructor-oriented data, nested structural patterns, guards, ordered cases, atomic bindings | Its language extensions and Python representation |
| [Python `functools`](https://docs.python.org/3.14/library/functools.html) | Reduction's left-to-right order and initial-value behavior | Keyword binding and placeholders in `partial` |
| [Toolz](https://toolz.readthedocs.io/en/latest/api.html) | Naming of `pipe`, `compose` and related combinators | — |
| [JAX `lax` control flow](https://docs.jax.dev/en/latest/jax.lax.html) | Sequential semantics of `while_loop`, `fori_loop` and `scan` | Tracing, pytrees, array stacking, autodiff, batching |
| [Boost.HOF](https://www.boost.org/doc/libs/latest/libs/hof/doc/html/include/boost/hof/compose.html) | Concrete stored function adaptors; composition distinguished by execution order (`compose`, [`flow`](https://www.boost.org/doc/libs/latest/libs/hof/doc/html/include/boost/hof/flow.html)) | Automatic repeated [partial](https://www.boost.org/doc/libs/latest/libs/hof/doc/html/include/boost/hof/partial.html) evaluation |
| [Boost.Hana Foldable](https://www.boost.org/doc/libs/latest/libs/hana/doc/html/group__group-_foldable.html) | One application point over heterogeneous products | A Hana-style container hierarchy; the library's own ADT products are used |
| [Boost.Parameter](https://www.boost.org/latest/libs/parameter/doc/html/reference.html) | Static keyword identity; signatures described separately from argument values | Macros and generated overload ceilings |
| [Rust closure call traits](https://doc.rust-lang.org/reference/types/closure.html#call-traits-and-coercions) | Shared, mutable and consuming receiver access, independent of capture ownership | Rust's closure ABI |

## Mojo documentation

- [Closures](https://mojolang.org/docs/manual/functions/closures/) and
  [lambda expressions](https://mojolang.org/docs/manual/functions/lambda/)
- [Errors and typed errors](https://mojolang.org/docs/manual/errors/)
- [Value semantics](https://mojolang.org/docs/manual/values/value-semantics/)
- [Parameters and compile-time evaluation](https://mojolang.org/docs/manual/parameters/)
- [Control flow](https://mojolang.org/docs/manual/control-flow/)
- [Compilation targets](https://mojolang.org/docs/tools/compilation/) and
  [GPU requirements](https://mojolang.org/docs/requirements/)
- Standard library: [iter](https://mojolang.org/docs/std/iter/),
  [itertools](https://mojolang.org/docs/std/itertools/),
  [Optional](https://mojolang.org/docs/std/collections/optional/Optional/),
  [Variant](https://mojolang.org/docs/std/utils/variant/Variant/),
  [memory](https://mojolang.org/docs/std/memory/),
  [reflection](https://mojolang.org/docs/std/reflection/),
  [testing](https://mojolang.org/docs/std/testing/)
- [Modular skills](https://github.com/modular/skills) for development guidance,
  always checked against the pinned compiler

Pinned upstream sources for Mojo 1.1.0 are listed in
[native Mojo boundaries](native-boundaries.md#reviewed-upstream-sources).

## License

FP Mojo is released under the Apache License 2.0; see `LICENSE` in the
repository. The bundled documentation fonts, Open Sans and Source Code Pro, are
distributed under their own licenses, included next to the font files.
