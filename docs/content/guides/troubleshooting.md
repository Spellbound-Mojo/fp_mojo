# Troubleshooting

Start by checking the compiler and the import path, then run a known example
next to your program:

```sh
pixi run mojo --version                                   # Mojo 1.1.0 (8189361e)
pixi run mojo run -I src docs/examples/quickstart.mojo    # prints 42
pixi run mojo run -I src my_program.mojo
```

If the example runs and your program does not, compare the failing call with
its declaration in the [API reference](../reference/index.md). Reduce it to a
small example while keeping the types, ownership conventions and errors that
trigger the failure.

## Symptoms

| Symptom | What to check |
|---|---|
| Cannot import fp | `src` or the package directory is missing from `-I`. Follow the source or package commands in [installation](../start/installation.md). |
| A copied value is required | A value that is not implicitly copyable was passed without a transfer. Choose an explicit `.copy()` or `^`, according to the semantics you intend. |
| Incompatible native error | A callback, projection or fallback raises a different error type. Map errors explicitly and select one common `E`. |
| `cannot call function that may raise '...Error' in context that supports an error type of 'Error'` when running a Reader or State computation | Mojo 1.1 does not reduce the computation's error alias in a plain `raises` context. Run it inside `try`/`except`; the caught error keeps its exact type. |
| `invalid redefinition of 'def(...)'`, or `cannot implicitly convert 'T' value to 'T'`, in a program with several modules | Two modules define a type with the same name and spell the same function type over it, and Mojo 1.1 treats the two function types as one. Rename the type in one module ([native boundaries](../architecture/native-boundaries.md#known-compiler-defects)); in the test suite, the build names the module to change. |
| `pipe: stage N should take X, return Y and raise …; it takes …` (or `flow:`, `compose:`) | Stage N's input, result or error does not fit the chain; stages count from 0 in the order they run. Fix that stage's types, or map its error to the chain's error. |
| `pipe: stage N must take one argument` | A closure or library value is mixed with native functions that are not promoted. Promote the native functions with `as_unary`. |
| `no matching function in call to 'match'` | A clause is not a plain function or a lambda without captures, or the clauses have more than three parameters. Pass the data a clause needs with `context=` instead of capturing it, and give each clause one parameter per subject, plus the context. |
| A `List` cannot be implicitly copied when passed to an iteration function | Collections are consumed as sources. Pass `values^` to consume it, or `iter(values)` to borrow it. |
| `fp.match: constructor X has no clause that cannot decline` | Every clause for `X` is a `when` clause, or there is none. Add a clause for `X` without a guard, or a catch-all that takes the whole `Node` type. |
| `fp.match: None has no clause that cannot decline` | A match on an `Optional` has no clause for an absent value. Add a clause taking `NoneType`, or a catch-all taking the whole `Optional`. |
| `Choice: field F of C is recursive` | A type with a recursive field was stored in a `Choice`. Use a `Node` for recursive data. |
| A `Result` or `Choice` cannot be implicitly copied into `fp.match((a, b), ...)` | The tuple holds its subjects. Write `(a.copy(), b)`, or move with `a^` when the value is no longer needed. |
| `fp.match: clause N is never selected` | An earlier clause for the same constructors cannot decline. Remove the clause, or guard the earlier one with `fp.when`. |
| `fp.match: clause N declares field F ... as T` | A field's declared type is neither the stored type nor, for a recursive field, the result type. Declare a recursive field as the result type to have it evaluated, or as the stored `Node` type to receive it as it is. |
| Generic callable cannot be inferred | The native callable encoding is outside the admitted form. Use the documented explicit `Results` or promotion form, or the thin-context form. |
| Generic pipeline result cannot convert to `R` | The inferred type expression has not been resolved to the declared result. Use the [checked generic wrapper](../tutorial/pipelines.md#forward-through-a-generic-function) with an explicit `E`, or an explicit `Results` path. |
| `partial` rejects the target | The function captures, has a `mut` or owned remaining parameter, or binds more than eight arguments. Write a native closure with an explicit capture list; see [partial](../reference/functions.md#partial). |
| The first build is slow, later ones fast | Mojo caches compiled parameter work. Measure compile time with an empty `MODULAR_CACHE_DIR`; see [benchmarks](../contributing/benchmarks.md). |
| O0 works, O3 fails for owned mutable capture | A known Mojo 1.1 lost-update defect affects certain encodings. Use an explicit mutable borrowed context instead of owned mutable closure state; see [native boundaries](../architecture/native-boundaries.md#known-compiler-defects). |

## Diagnose a match

`fp.match` checks clause types and coverage at compile time. Its diagnostics
name a constructor or a clause's position, counting from 0. At run time a match
tries the clauses for a value's constructor in the order
written. A `when` clause whose guard is false passes to the next one, and a
raised error ends the whole match at once.

## Keep error channels apart

Do not catch every exception and treat it as a failed match or the end of an
iterator. A `StopIteration` raised by a callback, a stored `Err`, an empty
reduction and the normal end of a source have different contracts. The
[ownership and errors](../start/ownership.md#keep-failure-channels-apart) guide
and the [results tutorial](../tutorial/results.md) show where each one is
handled.

## Report a compiler failure

A compiler crash or timeout is a tooling or compiler failure, never evidence
that a program is correctly rejected. Keep a minimal self-contained reproducer
with the compiler version, optimization level, target, source and diagnostics.
Pair an invalid program with a nearby valid one, and never run an invalid
program if the compiler unexpectedly accepts it.

[Native Mojo boundaries](../architecture/native-boundaries.md) lists the
Mojo 1.1 limitations and defects, along with supported alternatives that preserve
callback types and origins.

## Result fold does not compile

A `Result` fold with two raising branches can report a native constraint
diagnostic before any body-level message. Check the exact payload, result and
error types, including origins: both callbacks raise one error type, or one of
them raises nothing. A generic wrapper with two error parameters carries
`X == Never or Y == Never or X == Y` in its `where` clause.
