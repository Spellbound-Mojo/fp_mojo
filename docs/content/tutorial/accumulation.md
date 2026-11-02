# 10. Accumulating errors

A signup form can be wrong in three places at once. `flat_map` from
[chapter 3](results.md) and `traverse` from [chapter 8](algebra.md) return the
first stored error, which is the right rule when each step needs the previous
step's value. When the checks are independent, you can report every failure
together. This chapter combines independent Results so that their errors
accumulate, chooses the collection that holds those errors, and keeps a
value together with its warnings.

| Operation | Which checks run | What a failure reports |
|---|---|---|
| `flat_map` | Each step, only after the previous one succeeded | The first `Err` |
| `map_n`, `product_n` over Result | Every operand, before the call | The first `Err`, receiver first |
| `par_map_n`, `par_product_n` | Every operand, before the call | Every `Err`, combined in order |
| `traverse` into `ResultFamily` | Elements up to the first `Err` | The first `Err` |
| `par_traverse` | Every element | Every `Err`, in source order |

## Report the first error or every error

Each check in this example returns `Result[T, List[String]]`: the field as
`Ok`, or a one-element list of problems as `Err`. The form under test has an
empty name, a five-byte password and an age of 12, so all three checks fail.

<!-- example: docs/examples/accumulate_signup.mojo -->

`map_n` combines the three Results with the Result Applicative from chapter 8.
Mojo evaluates the arguments before the call, so all three checks have
already run. `map_n` keeps the receiver's error, `name is empty`, destroys
the other two, and never calls `signup`. The first line reports one problem.

`par_map_n` takes the same arguments and concatenates the stored lists in
receiver-first order, so the second line reports all three problems. Had
every operand been `Ok`, it would move the three payloads into `signup`
and call it once. `product_n` and `par_product_n` are the tuple forms of
these methods: for a valid name and age, `par_product_n` returns
`Ok(("ana", 30))`, which `show_fields` borrows and prints as `ana, 30`.

Both methods consume their operands and execute immediately. The `par_`
prefix selects error accumulation; it does not start threads. `signup` is
borrowed for the call and its payloads are moved, not copied.

### Select the validation family

`par_map_n` is `map_n` under another Applicative instance.
`ValidationFamily[S]` keeps the native `Result` carrier and changes one rule:
when two operands fail, their errors are combined with `S`. The example
selects `ValidationFamily[ListMonoid[String]]` with `pipeline[Validation]`,
and its `map_n` produces the same three problems as `par_map_n`; the
assertion compares the two texts. For `List[E]` errors the `par_` methods
infer `ListMonoid[E]`, so you name the family only in generic code or to
choose another policy.

## Run a dependent check after the independent ones

`ValidationFamily` has no `flat_map`: it is an Applicative, not a Monad. A
dependent step needs the previous value, and when a field fails there is no
form to pass to it, so the step cannot run and there is no second error to
combine. `register` therefore combines the fields with `par_map_n` and then
continues with `flat_map(distinct)`. The pipeline still holds a `Result` in
`ResultFamily`, so this is the monadic bind from chapter 3.

- `"ana"`, `"correct-horse"` and 30 pass every field check. `distinct` runs,
  prints its line, and returns `Ok`, so the result is `welcome ana, age 30`.
- `"ana"`, `"ana-secret"` and 30 also pass the field checks, but `distinct`
  finds the name inside the password and returns
  `password contains the name`.
- `""`, `"short"` and 12 fail all three field checks. `flat_map` skips
  `distinct`, so no `comparing` line precedes `skipped:`, and the result keeps
  the three accumulated problems.

Order the checks this way in your own validators: accumulate the checks that
need only their own input, then sequence the checks that need a combined value.

## Validate every element of a source

`par_traverse` applies a validator to every element of a finite source and
keeps every stored error in source order. `par_sequence` does the same for
Results that already exist.

<!-- example: docs/examples/parallel_validation.mojo -->

`positive` fails for values that are not positive. The first two lines repeat
the n-ary case: 2, 3 and 4 give `total: 9`, while -2 and -4 are both reported.

`check` is a Kleisli chain that validates a value and then squares it.
`pipeline(List[Int]([2, -3, 4, -5])).par_traverse(check)` calls it for all four
elements and reports -3 and -5 together. The squares of 2 and 4 are computed,
but a failed traversal returns only its errors. With `traverse` and
`ResultFamily`, the traversal would have stopped at -3 and never checked 4
or -5. `iterated(range(1, 4)).par_traverse(check)` consumes an iterator over
1, 2 and 3 and collects a List; every check passes, and the result holds 1, 4
and 9. The same chain is borrowed by both calls. `par_product_n` keeps the
pair `2 3`, and `par_sequence` collects three finished Results and reports
both of their failures.

A List or iterator source calls the validator once per element, so the
validator must support repeated calls. An Optional or Result source calls it
at most once. An empty source succeeds with an empty collection and calls
nothing. If the validator raises a native error, the traversal stops at once
and the error keeps its type; raised errors never become stored validation
errors.

## Choose how errors combine

The error policy is a *semigroup*: an associative `combine` of two values,
with no identity. Validation needs nothing more, because it combines errors
only when two failures meet; it never needs an empty error to start from.
`ListMonoid[E]` concatenates lists and is the inferred policy for `List[E]`
errors. Pass any other policy explicitly:

```text
.par_map_n[Policy]((second, third), construct)
.par_product_n[Policy]((second, third))
.par_traverse[Policy](validate)
.par_sequence[Policy]()
traverse[ValidationFamily[Policy], SourceFamily](source^, validate)
```

The last form is the generic `traverse` with an explicit source family. A
policy is a struct conforming to `Semigroup`, with a `Value` type and a static
`combine(left, right)` that consumes both values. `StringMonoid`, for example,
concatenates scalar String errors. If `combine` can raise, it declares a native
`Error` type, and that error propagates instead of becoming stored. Order is
kept: the receiver's error comes first. Associativity guarantees that grouping
the failures differently gives the same result.

## Guarantee at least one error with NonEmptyList

A `List[String]` error has one value that means nothing: `Err` with an empty
list. That value type-checks, and `par_map_n` keeps it an `Err`, so a caller
can receive a rejection with no reasons. `report` in the first example would
print `rejected: ` and stop.

`NonEmptyList[T]` rules that value out. Its constructors take a first element:
`NonEmptyList(first)` or `NonEmptyList(first, rest)`. To check an existing
List, `NonEmptyList[T].from_list(values^)` returns an `Optional` that is empty
for an empty List, and `NonEmptyList[T](values=values^)` raises `Error`.
Nothing removes elements. In exchange, `first()` returns a reference rather
than an `Optional`, and `len` is at least one.

`NonEmptyListSemigroup[E]` concatenates two non-empty lists in order, moving
every element. It is a semigroup and not a monoid: a monoid needs an identity,
and an empty `NonEmptyList` does not exist. Because validation needs only a
semigroup, the two fit together. The `par_` methods infer a policy only for
List errors, so you pass this one explicitly:

<!-- example: docs/examples/non_empty_validation.mojo -->

`positive` returns `Err(NonEmptyList(message))`, a singleton. With
`par_map_n[Errors]`, both -1 and -2 fail, so `show_errors` receives two
messages. It consumes the collection with `for error in errors^`, moving each
message out. NonEmptyList iteration consumes the collection.

The traversal names both families: first the Applicative the validator
returns into, `ValidationFamily[Errors]`, then the source,
`NonEmptyListFamily`. Every input is positive, so the result is `Ok` holding
a `NonEmptyList[Int]`: a successful traversal keeps the non-empty shape, and
its first element is 2.
Reductions such as `reduce_non_empty` and `minimum_by_non_empty` use the same
guarantee to work without a starting value; see
[non-empty sources](../reference/iteration.md#use-a-non-empty-source-guarantee).

## Keep a value with its warnings

Some inputs can be repaired. A name with surrounding spaces can be trimmed,
and the caller should still hear about it. `Ior[E, A]`, an inclusive-or, has
three constructors:

| Constructor | Holds | Meaning in this chapter |
|---|---|---|
| `Left(E)` | Diagnostics without a value | The input was rejected |
| `Right(A)` | A value without diagnostics | The input was accepted unchanged |
| `Both(E, A)` | Diagnostics and a value | The input was accepted with warnings |

Ior has two families and neither is inferred, so name one for algebra and
`pipeline` operations:

| Family | When a step has no value | When it has a value and diagnostics |
|---|---|---|
| `IorFamily[S]` | Skips dependent steps and stops a traversal | Continues and keeps the diagnostics |
| `IorValidationFamily[S]` | Still evaluates the remaining operands | Keeps a value only if every operand has one |

Both families combine two present diagnostics with `S` and never need an
empty value, so `NonEmptyListSemigroup` works here as well.

<!-- example: docs/examples/accumulate_warnings.mojo -->

`checked_name` trims its input: `"ana"` gives `Right`, `" ana "` gives `Both`
with the warning `name trimmed`, and `" "` gives `Left`. `checked_age` lowers
150 to 120 with a warning and rejects -4. `review` combines the two outcomes
with `map_n` under `IorValidationFamily`:

- `"ana"` and 30 both give `Right`, so `profile` runs once and the result is
  `Right`: `accepted ana, 30`.
- `" ana "` and 150 both give `Both`. `profile` receives `"ana"` and 120, and
  the two warnings are combined in order: two warnings, the first being
  `name trimmed`.
- `" ana "` and -4 leave no age. `profile` is not called and the trimmed name
  is destroyed, but its warning is combined with the age error, so the `Left`
  holds both.
- `" "` and -4 are both `Left`, and both errors are reported.

`describe` tests the constructor with `isa`. The `Left` branch consumes the
outcome with `unwrap` and moves the diagnostics out with `into_payload`. The
other branches borrow fields through constructor indexing, as in
`outcome[Both[Notes, Profile]]`; `first()` then borrows the first warning
without an `Optional` check. You can also match the three constructors
exhaustively with `fp.match`, as in [chapter 4](matching.md).

### Stop at the first rejection or check every input

The two families differ most over a collection:

<!-- example: docs/examples/ior_validation.mojo -->

`checked(0)` returns `Both` with the warning `zero accepted`. Mapping it under
`IorFamily` applies `twice` to 0 and keeps the warning. Traversing `[0, -2, -3]`
with `IorValidationFamily` visits all three inputs and returns `Left` with
three diagnostics: the warning and both errors. `IorFamily` stops after the
first `Left`, at -2, so its `Left` holds the warning and one error, and -3 is
never checked. When every input has a value, either family returns `Both`
with the collected warnings, or `Right` if there were none.

`IorFamily` also provides `flat_map`: a dependent step runs on `Right` or
`Both`, and earlier diagnostics come before later ones. `IorValidationFamily`
is an Applicative only, for the same reason as `ValidationFamily`. A native
error raised by a check stops either family at once; it never becomes `Left`
or `Both`. Ior cannot be a traversal source, and it has no error recovery
such as the `recover` and `or_else` operations from chapter 3. See
[success with warnings](../reference/data.md#success-with-warnings) for the
full contract.

Next, continue with chapter 11,
[Programming against capabilities](capabilities.md).
