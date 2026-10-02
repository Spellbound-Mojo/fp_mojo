# Support and limitations

This page states what FP Mojo 0.2.0 supports and known limitations. Details of every limitation that comes from the compiler are in
[native Mojo boundaries](../architecture/native-boundaries.md).

## Platforms

| Item | Status |
|---|---|
| Compiler | Mojo 1.1.0 (8189361e), pinned through Pixi; other versions are not supported |
| Linux x86-64 | Supported and verified |
| macOS arm64 | Supported and verified |

## Limitations

### Partial application

`partial` binds a positional prefix of up to eight arguments of a plain function.
It does not bind keywords, reorder arguments, accept capturing targets, `mut`
parameters or owned remaining parameters, or nest. A native closure expresses all
of these.

### Callbacks

- Lazy iteration callbacks cannot raise; carry failures as `Result` elements.
- Visitor handlers take closures with up to four values and plain functions
  with up to eight; wider records use `on_fields_owned`.
- `fp.match` and `fp.rewrite` take one to sixteen clauses: plain functions or
  lambdas without captures. Data a clause needs is passed with `context=` or as
  a component of a tuple of values.
- `pipe`, `flow` and `compose` take two to eight plain functions directly. A
  closure is promoted with `as_unary`, and then every native function in that
  chain is promoted too. `piped(value).then(f)...get()` chains any number of
  plain functions, closures and library values.
- `action` takes library endpoints (`BorrowCallable` for Reader, `Unary` for
  State): a plain function with read parameters would match both native forms.
- Algebra and effect callbacks are native functions or closures for `map`,
  `flat_map`, `traverse`, `modify`, `censor` and `local`; `map2`, `map2_lazy` and
  `ap` take library values.
- `attempt`'s native overloads take zero to two positional arguments and
  homogeneous native keyword packs; other call shapes are written as a closure.
- A native function with named or defaulted parameters is passed to library
  functions through a closure that spells the call.
- Closures that own mutable state can lose updates at O3 on Mojo 1.1 when called
  through a read borrow. Use an explicit mutable borrowed context instead.
- Some closures that combine embedded origins with captured state fail to
  compile on Mojo 1.1; pass borrowed views as arguments instead.
- Two modules of one program that define same-named types and spell the same
  function type over them fail to compile on Mojo 1.1 (`invalid redefinition of
  'def(...)'`); give those types distinct names
  ([details](../architecture/native-boundaries.md#known-compiler-defects)).

### Generic code

Generic wrappers must follow the spellings shown in the tutorials: pass `E=E`
explicitly, keep the documented parameter names, and keep the nominal type
assertion next to `rebind_var`. The reasons are in
[native Mojo boundaries](../architecture/native-boundaries.md#generic-code).

### Data and matching

- Matches borrow their subject and return values, never references into it;
  consuming access belongs to the types (`Result.fold_owned`, `Choice.unwrap`,
  `Optional.take`).
- A guard is opaque to coverage: a guarded clause never covers a constructor
  alone.
- Sixteen clauses per match and three subjects; clauses do not capture, so data
  they need comes through `context=` or a subject.
- A native `Variant` is not a match subject; declare the type with `Data` and
  store it in a `Choice`.
- See [limits](../architecture/matching.md#limits) for the full list.

### Algebra and effects

- `local` rejects a base whose result keeps the environment.
- A Reader or State computation built by `map`, `flat_map` or `traverse` from a
  native function or closure borrows it until the computation runs; keep it
  alive and unmoved, or move it in with `as_unary(f^)`.
- Running a deferred computation whose callback raises cannot propagate from a
  function declared with a plain `raises`; catch the error with `try`/`except`,
  where it keeps its exact type.
- State traversal requires a base whose carrier keeps one type across steps.
- `pure` over `WriterT` requires a monoid whose `empty` does not raise.
