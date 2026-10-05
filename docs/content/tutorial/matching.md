# 4. Data and matching

A data type lists its constructors, a value holds one of them, and a match gives
one clause per constructor to say what each means. `fp.match` checks the
clauses when the program compiles, so a match that misses a constructor does not
build, and then runs the clause for the constructor the value holds. Clauses are
plain functions or lambdas without captures; data they need arrives through a
context or as another matched value.

## Declare a type and match it

<!-- example: docs/examples/shapes.mojo -->

The program prints one line per shape: `a circle 3.0 12.0`,
`a rectangle 6.0 24.0`, `a square 4.0 16.0` and `something else 0.0 0.0`.

- **Constructors are ordinary structs.** `Circle`, `Rect` and `Dot` are
  `@fieldwise_init` structs. `Shape` lists them in a `Cases`, and
  `Node[Shape]` holds one of them. A constructor converts to a `Node`
  implicitly, so `S(Circle(1.0))` and `var s: S = Dot()` both work.
- **A clause's parameter type selects its constructor.** `fp.match(s, ...)`
  calls the clause for the constructor `s` holds and returns its result. Every
  clause returns the same type: `area` returns `3.0` for `Circle(1.0)`.
- **Every constructor must be handled.** Leave out the `Dot` clause in `area`
  and the program does not compile:
  `fp.match: constructor Dot has no clause that cannot decline`.
- **A parameter of the whole type is a catch-all.** In `describe`, the last
  clause takes `S` and handles every constructor that no earlier clause
  handled, so `Dot()` gives `"something else"`.

## Add a guard to a clause

`fp.when[guard, clause]` is a clause that applies only when `guard` returns
`True` for the same argument. When it returns `False`, the next clause for that
constructor is tried. In `describe`, the square clause takes `Rect(2.0, 2.0)`
but declines `Rect(2.0, 3.0)`, whose sides differ, and the plain `Rect` clause
returns `"a rectangle"`. A guarded clause alone never covers a constructor, so
the plain `Rect` clause is required.

Clauses are tried in the order written, and the first that applies is used. A
clause that can never be selected, because an earlier clause for the same
constructor cannot decline, is a compile-time error.

## Pass data through a context

Clauses do not capture variables. Pass data that every clause needs, such as a
scale factor or an environment, with `context=`; it arrives as each clause's
second parameter. `scaled_area(s, 2.0)` multiplies each area by `2.0 * 2.0`, so
the circle's `3.0` becomes `12.0`. The match borrows the context.

## Several values at once

`fp.match((a, b), ...)` matches two values together, and `(a, b, c)` three.
Each clause takes one parameter per value, and the first clause whose parameters
all apply is used. In `shapes.mojo`, `same_kind` returns `True` for two
rectangles and `False` for a circle and a dot.

<!-- example: docs/examples/traffic_light.mojo -->

`step` combines a light with an event. Starting from red, four ticks give
`green`, `amber`, `red` and `green`, and its last clause turns an outage into
`red` in any state. Every combination of constructors must be covered.

In `report`, the third value is a plain `Int`. A value that is not a `Node`
takes part as it is, and guards can test it: `report(L(Red()), tick, 5)`
returns `"red with a queue of 5"` because the guard `n > 3` holds, while a green
light with a tick and `0` reaches the last clause, `"normal"`.

## Raise from a clause

A clause may raise. Every clause raises nothing or one common error type, and
the match raises that type unchanged; the first raise stops the match. The
[job router](application.md#route-commands-with-guarded-clauses) dispatches
through guarded clauses that raise a typed error.

The rules are summarized in [algebraic data and matching](../architecture/matching.md).
Next, store values of a type without recursive fields [in place](choices.md), and
match `Result` and `Optional` the same way.
