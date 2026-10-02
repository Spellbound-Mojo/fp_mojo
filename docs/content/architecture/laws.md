# Laws

Algebraic laws are part of each operation's contract, stated together with the
assumptions under which they hold. The library does not prove them: a trait
conformance is never advertised as evidence of lawfulness. Laws are checked by
tests over representative types, which is evidence, not proof.

## Assumptions

The equations below use ordinary mathematical equality. They hold for
well-typed operations whose callbacks are **pure** and **terminating**, and whose
values have equivalent native ownership and copy behavior on both sides of the
equation. Ownership transfers are implicit in the notation.

Callbacks with effects are allowed everywhere in the library, but for them the
contract is the specified invocation order and count, not an equation. Tests of
stateful callbacks check the observable trace of calls instead.

## Functions

```text
identity(x)                          = x
compose(identity, f)(x)              = f(x)
compose(f, identity)(x)              = f(x)
compose(h, compose(g, f))(x)         = compose(compose(h, g), f)(x)
pipe(x, f, g)                        = g(f(x))
```

## Functors and monads

For every instance `I` (`IdentityFamily`, `OptionalFamily`, `ResultFamily[E]`,
`ListFamily` and the transformers):

```text
map[I](identity, v)                  = v
map[I](g, map[I](f, v))              = map[I](compose(g, f), v)

flat_map[I](f, pure[I](x))           = f(x)
flat_map[I](pure[I], m)              = m
flat_map[I](g, flat_map[I](f, m))    = flat_map[I](x -> flat_map[I](g, f(x)), m)
```

For `ResultFamily[E]` the laws hold on both cases: an `Err` passes through every
operation unchanged, because callbacks never run on the inactive case. The
instance's operations are the Result methods, so `map[ResultFamily[E]](f, r)` is
`r.map(f)` and `flat_map[ResultFamily[E]](f, r)` is `r.flat_map(f)`.

Traversal preserves the source's shape and callback order, and stops at the
first failure or absence without pulling another element; these are tested as
observable behavior rather than as equations.

## Monoids

```text
combine(empty(), a)                  = a
combine(a, empty())                  = a
combine(combine(a, b), c)            = combine(a, combine(b, c))
```

`StringMonoid` and `ListMonoid[A]` satisfy these because they are standard
concatenation; the tests check their `empty` and `combine` values. A third-party
monoid is responsible for its own laws. `WriterT` combines logs in execution
order.

## Matching

```text
fp.match(C(fields), clauses)         = the first clause for C, or a catch-all, that applies
```

Exactly one clause produces the result, and declining guards run in clause
order before it. The value matched is unchanged: a match borrows its subject,
whether a `Node`, a `Choice`, a `Result` or an `Optional`.

## Folds

For finite inputs and compatible value semantics:

```text
fold_left(step, init, chain(xs, ys)) = fold_left(step, fold_left(step, init, xs), ys)
```

This law does not require `step` to be associative, and the tests use
subtraction to make that visible. Reassociating a reduction would need
additional assumptions and is never done implicitly.

Lazy adapters obey the list laws of their eager counterparts: `map` preserves
order and length, `map(g, map(f, xs))` equals `map(compose(g, f), xs)`, `filter`
keeps the relative order of accepted elements, and `flat_map` equals `map`
followed by `flatten`.

## Where the laws are tested

| Area | Tests |
|---|---|
| Pipelines and composition | `tests/laws/test_callable_pipeline_inferred_laws.mojo`, `test_foundation_qualification_laws.mojo` |
| Folds | `tests/laws/test_fold_laws.mojo` |
| Lazy iteration | `tests/laws/test_iteration_laws.mojo` |
| Result | `tests/laws/test_result_laws.mojo` |
| Matching | `tests/runtime/test_match_single.mojo`, `test_match_inline.mojo`, `test_match_tuples.mojo` |
| Algebra instances | `tests/runtime/test_algebra.mojo` (functor and monad laws, derived operations, monoid values) and the `test_algebra_*` runtime tests (traversal order, pulls and layering) |

A generic "map over every field of matching type" is deliberately absent:
reflection alone does not say which fields a lawful mapping should change, so a
mapping needs a declared semantic parameter that preserves constructor structure
and unrelated fields.
