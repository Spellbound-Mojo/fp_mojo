# 5. Algebraic data types stored in place

Use `Choice[F]` for a non-recursive algebraic data type whose value should be
stored in place. It holds one constructor inside a native `Variant`, without
allocating storage for the `Choice` itself. Declare the constructors with
`Cases`, as in [chapter 4](matching.md), and match them with `fp.match`.

`Choice` uses the same clause syntax as `Node`. The distinction is storage:
`Node` supports shared values and recursive fields, while `Choice` owns a
constructor directly. A bare native `Variant` is not a match subject.

## Store a value in a Choice

<!-- example: docs/examples/foundations.mojo -->

`fold_left(add, 0, range(1, 6))` returns `15` after five calls to `add`.
`Pair(total, 7)` converts to `Choice[Term]`, and the match calls the `Pair`
clause, which returns `15 + 7 = 22`. `attempt(checked)` wraps that answer in
`Ok`, and `raise_on_err` returns `22` without raising. The program prints
`fold = 15 ; match = 22 ; callbacks = 5`.

`Term` lists its constructors in `Cases`, and a constructor converts implicitly
to `Choice[Term]`. Copying a `Choice` copies that constructor, so `Choice` is
`Copyable` only when every constructor is. It can also store a constructor that
is only `Movable`; `unwrap[C]()` moves the constructor out again.

A match clause borrows the stored constructor without copying it. A clause
taking the whole `Choice[Term]` acts as a catch-all. For direct inspection, use
`value.isa[Pair]()`, `value[Pair]` or `value == Pair(15, 7)`.

A type with a recursive field cannot be a `Choice`. The compiler reports
`Choice: field left of Plus is recursive; a value of a recursive data type is a
Node`. Recursive data is the subject of the [next chapter](recursion.md).

## Match Result, Optional and ControlFlow

<!-- example: docs/examples/optional.mojo -->

`sum_or_missing` returns `42` for the list `[10, 12, 20]` and `-1` for `None`.
`describe` returns `"large"` for `Ok(42)`, `"small"` for `Ok(7)` and
`"failed: no data"` for `Err("no data")`.

- **Result** holds `Ok[T]` or `Err[E]` in place, and clauses take those
  constructors. The guarded clause in `describe` applies only to values above
  40. The methods `map`, `flat_map`, `fold` and the rest work as before; a match
  is the form that checks every case and allows guards.
- **Optional** is the standard type. A clause takes the value's type for a
  present value and `NoneType` for an absent one, or `Optional[T]` as a
  catch-all. The match borrows, so the list is still in `subject` afterwards.
- **ControlFlow**, the result of `fold_until`, is a `Choice` of `Break[B]` and
  `Continue[C]`.

Every kind of value can take part in a match of several values:
`fp.match((result, optional), ...)` covers every combination of `Ok` or `Err`
with present or absent. The tuple holds its values, so copy a value that is not
implicitly copyable into it with `.copy()`, or move it with `^`.

## Take a value out

Matching only borrows. To take a value out, use the consuming methods of the
type: `Result.fold_owned` or `raise_on_err`, `Optional.take()`, or
`Choice.unwrap`.

For the API, see [fp.adt](../reference/adt.md), [fp.data](../reference/data.md)
and [fp.matching](../reference/matching.md). Next, declare
[recursive data](recursion.md).
