# 4. Data and matching

A data type lists its constructors; a value holds one of them; a match says, one
clause per constructor, what each means. The library checks the clauses when the
program compiles and runs the match for you.

## Declare a type and match it

<!-- example: docs/examples/shapes.mojo -->

- **Constructors are ordinary structs.** `Circle`, `Rect` and `Dot` are
  `@fieldwise_init` structs. `Shape` lists them in a `Cases`, and
  `Node[Shape]` holds one of them. A constructor converts to a `Node`
  implicitly, so `S(Circle(1.0))` and `var s: S = Dot()` both work.
- **A clause is a lambda or a plain function.** Its parameter type selects
  the constructor it handles. `fp.match(s, ...)` calls the clause for the
  constructor `s` holds and returns its result; every clause returns the same
  type.
- **Every constructor must be handled.** Leave out the `Dot` clause in `area`
  and the program does not compile:
  `fp.match: constructor Dot has no clause that cannot decline`.
- **A parameter of the whole type is a catch-all.** In `describe`, the last
  clause takes `S` and handles every constructor not handled before it.

## Guards

`fp.when[guard, clause]` is a clause that applies only when `guard` returns
true for the same argument. Otherwise the next clause for that constructor is
tried. In `describe`, the square clause declines a rectangle whose sides
differ, and the following `Rect` clause takes it. A guarded clause alone never
covers a constructor, so the plain `Rect` clause is required.

Clauses are tried in the order written, and the first that applies is used. A
clause that can never be selected, because an earlier clause for the same
constructor cannot decline, is a compile-time error.

## Context

Clauses do not capture variables. Data that every clause needs, such as a scale
factor or an environment, is passed with `context=` and arrives as each
clause's second parameter, as in `scaled_area`. The context is borrowed.

## Several values at once

`fp.match((a, b), ...)` matches two values together, and `(a, b, c)` three.
Each clause takes one parameter per value, and the first clause whose
parameters all apply is used:

<!-- example: docs/examples/traffic_light.mojo -->

`step` combines a light with an event, and its last clause handles an outage
in any state. Every combination of constructors must be covered. In `report`,
the third value is a plain `Int`: a value that is not a `Node` takes part as it
is, and guards can test it.

## Errors

A clause may raise. Every clause raises nothing or one common error type, and
the match raises that type unchanged; the first raise stops the match. The
[job router](../examples/index.md) dispatches through guarded clauses that raise
a typed error, and compares every route with a hand-written branch.

The rules are summarized in [algebraic data and matching](../architecture/matching.md).
Next, store values of a type without recursive fields [in place](choices.md), and
match `Result` and `Optional` the same way.
