# Support and limitations

This page lists the compilers and platforms FP Mojo supports and the boundaries
you may meet when you use it. Each boundary says what the library does today.
The details of every boundary that comes from the compiler are in
[native Mojo boundaries](../architecture/native-boundaries.md).

## Platforms

| Item | Status |
|---|---|
| Compiler | Mojo 1.1.0 (8189361e), pinned through Pixi; other versions are not supported |
| Linux x86-64 | Supported and verified |
| macOS arm64 | Supported and verified |

## Known boundaries

| Area | Current behavior |
|---|---|
| Partial application | `partial` binds a positional prefix of up to eight arguments of a plain function. It does not bind keywords, reorder arguments, accept capturing targets, `mut` parameters or owned remaining parameters, or nest. A native closure expresses all of these. |
| Lazy iteration callbacks | They cannot raise; carry failures as `Result` elements. |
| Match clauses | `fp.match` and `fp.rewrite` take one to sixteen clauses: plain functions or lambdas without captures. Data a clause needs is passed with `context=` or as a component of a tuple of values. |
| Pipeline stages | `pipe`, `flow` and `compose` take two to eight plain functions directly. A closure is promoted with `as_unary`, and then every native function in that chain is promoted too. `piped(value).then(f)...get()` chains any number of plain functions, closures and library values. |
| `action` endpoints | `action` takes library endpoints (`BorrowCallable` for Reader, `Unary` for State): a plain function with read parameters would match both native forms. |
| Algebra and effect callbacks | `map`, `flat_map`, `traverse`, `modify`, `censor` and `local` take native functions or closures; `map2`, `map2_lazy` and `ap` take library values. |
| `attempt` call shapes | The native overloads take zero to two positional arguments and homogeneous native keyword packs; write other call shapes as a closure. |
| Named or defaulted parameters | Pass a native function with named or defaulted parameters to library functions through a closure that spells the call. |
| Closures with owned mutable state | They can lose updates at O3 on Mojo 1.1 when called through a read borrow. Use an explicit mutable borrowed context instead. |
| Closures with embedded origins | Some closures that combine embedded origins with captured state fail to compile on Mojo 1.1; pass borrowed views as arguments instead. |
| Same-named types in several modules | Two modules of one program that define same-named types and spell the same function type over them fail to compile on Mojo 1.1 (`invalid redefinition of 'def(...)'`); give those types distinct names ([details](../architecture/native-boundaries.md#known-compiler-defects)). |
| Generic wrappers | Follow the spellings shown in the tutorials: pass `E=E` explicitly, keep the documented parameter names, and keep the nominal type assertion next to `rebind_var`. The reasons are in [native Mojo boundaries](../architecture/native-boundaries.md#generic-code). |
| Match ownership | Matches borrow their subject and return values, never references into it; consuming access belongs to the types (`Result.fold_owned`, `Choice.unwrap`, `Optional.take`). |
| Guards and coverage | A guard is opaque to coverage: a guarded clause never covers a constructor alone. |
| Match size | Sixteen clauses per match and three subjects; clauses do not capture, so data they need comes through `context=` or a subject. |
| Native `Variant` | A native `Variant` is not a match subject; declare the type with `Data` and store it in a `Choice`. The [matching limits](../architecture/matching.md#limits) give the full list. |
| `local` | `local` rejects a base whose result keeps the environment. |
| Deferred Reader and State callbacks | A Reader or State computation built by `map`, `flat_map` or `traverse` from a native function or closure borrows it until the computation runs; keep it alive and unmoved, or move it in with `as_unary(f^)`. |
| Running a raising deferred computation | Its error cannot propagate from a function declared with a plain `raises`; catch it with `try`/`except`, where it keeps its exact type. |
| State traversal | Requires a base whose carrier keeps one type across steps. |
| `pure` over `WriterT` | Requires a monoid whose `empty` does not raise. |

When a program runs into one of these boundaries,
[troubleshooting](troubleshooting.md) lists the compiler messages and what to
check for each.
