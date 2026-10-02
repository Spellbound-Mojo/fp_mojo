# 5. Values stored in place

Let us start building towards Algebraic Data Types (ADT). First, we introduce a
`Choice` type that holds one of its constructors in place, like native
`Variant` type. Both are concrete implementation of ADT Sum type. We opted to implement `Choice` for performance reasons, as opposed to sticking with native `Variant`. Conceptually, they are very similar, `Choice` is just used for pattern matching.

## A Choice

<!-- example: docs/examples/foundations.mojo -->

- **The declaration is the same.** `Term` lists its constructors in a `Cases`,
  as in [chapter 4](matching.md). `Choice[Term]` holds one of them, and a
  constructor converts to it implicitly.
- **Owned, not shared.** A `Choice` lives where it is declared, with no
  allocation, like a native `Variant`. Copying it copies the constructor, and it
  is `Copyable` only when every constructor is. A constructor that is only
  `Movable` can be stored, and `unwrap[C]()` moves it out again.
- **Matching.** A clause takes a constructor, or the whole
  `Choice[Term]` as a catch-all. A clause receives a reference to the
  stored constructor, so nothing is copied.
- **Inspected like a Variant.** `value.isa[Pair]()`, `value[Pair]` and
  `value == Pair(15, 7)` read it without a match.

A type with a recursive field cannot be a `Choice`: `Choice: field left of
Plus is recursive; a value of a recursive data type is a Node`. Recursive data
is the subject of the [next chapter](recursion.md).

## Result, Optional and ControlFlow

<!-- example: docs/examples/optional.mojo -->

- **Result** holds `Ok[T]` or `Err[E]` in place. Clauses take those
  constructors. The guarded clause in `describe` applies only to large values.
  Its methods (`map`, `flat_map`, `fold`, ...) are unchanged; a match is the
  form that checks every case and allows guards.
- **Optional** is the standard type. A clause takes the value's type for a
  present value and `NoneType` for an absent one, or `Optional[T]` as a
  catch-all. The match borrows: the list is still in `subject` afterwards.
- **ControlFlow**, the result of `fold_until`, is a `Choice` of `Break[B]` and
  `Continue[C]`.

Every kind of value can take part in a match of several values:
`fp.match((result, optional), ...)` covers every combination of `Ok`/`Err` with
present/absent. The tuple holds its values, so a value that is not implicitly
copyable is copied into it with `.copy()` or moved with `^`.

Matching only borrows. To take a value out, use `Result`'s consuming methods
(`fold_owned`, `raise_on_err`), `Optional.take()`, or `Choice.unwrap`.

For the API, see [fp.adt](../reference/adt.md), [fp.data](../reference/data.md)
and [fp.matching](../reference/matching.md). Next, declare
[recursive data](recursion.md).
