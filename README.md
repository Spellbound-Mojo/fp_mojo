# FP Mojo

**Functional programming for Mojo.**

Pipelines, composition, lazy iterators, typed results, algebraic data types
with exhaustive pattern matching, and Functor/Monad-style effects, built for
Mojo!

![Mojo 1.1.0](https://img.shields.io/badge/Mojo-1.1.0-orange)
![Platforms](https://img.shields.io/badge/platforms-Linux%20x86--64%20%7C%20macOS%20arm64-blue)
![License](https://img.shields.io/badge/license-Apache%202.0-green)

```mojo
from fp.functions import pipe
from fp.iteration import map, filter, fold_left

def positive(value: Int) -> Bool: return value > 0
def square(value: Int) -> Int: return value * value
def add(total: Int, value: Int) -> Int: return total + value

def sum_of_squares(var values: List[Int]) -> Int:
    # Lazy: filter and map run one element at a time as fold_left pulls.
    return fold_left(add, 0, map(square, filter(positive, values^)))

def report(total: Int) -> String: return "sum of squares = " + String(total)

def main():
    var values: List[Int] = [3, -1, 4, -1, 5]
    print(pipe(values^, sum_of_squares, report))   # sum of squares = 50
```

## Why FP Mojo

- **Native all the way down.** Your data stays in `List`, `Optional`, `Variant`,
  tuples and your own structs. Callbacks are plain Mojo functions and closures.
  Nothing is boxed, erased or interpreted.
- **Ownership-aware.** Move-only values, borrowed views and `var`, read and `mut`
  conventions pass through every operation unchanged. References keep their
  origins, so a borrowed payload cannot escape its scope.
- **Errors keep their type.** A callback that `raises ParseError` makes the
  pipeline, fold or match raise `ParseError`. A stored `Err` stays data and
  never turns into an exception by accident.
- **Checked by the compiler.** Matches must handle every constructor, a match
  clause that can never run is an error, and a pipeline stage with the wrong
  input type is a compile error that names the stage.
- **Recursion without recursive calls.** Match clauses declaratively specify
  behavior, which the library evaluates iteratively with built-in termination
  guarantees.

## What's inside

| Package | What it gives you | Highlights |
|---|---|---|
| `fp.functions` | Pipelines and composition | `pipe`, `piped`, `flow`, `compose`, `flip`, `partial`, `identity` |
| `fp.iteration` | Lazy adapters and terminal folds over iterators and owned collections | `map`, `filter`, `filter_map`, `flat_map`, `flatten`, `scan_left`, `fold_left`, `fold_until`, `reduce`, `find`, `any`, `all`, `collect_list` |
| `fp.control` | Loops as expressions | `while_loop`, `fori_loop`, carry/output `scan` |
| `fp.data` | Typed results and error bridges | `Result` with `map`, `flat_map`, `map_err`, `or_else`, `fold`; `attempt`, `raise_on_err`, `collect_results`, `ControlFlow` |
| `fp.adt` | Algebraic and recursive data types from your own structs | `Data`, `Cases`; `Node` (shared, recursive) and `Choice` (stored in place) |
| `fp.matching` | Pattern matching | `fp.match` (a `Node`, `Choice`, `Result` or `Optional`, a context, or several values), `fp.rewrite`, `fp.when`, `Next` |
| `fp.algebra` | Functor, Applicative, Monad, Traversable and Monoid | `map`, `pure`, `flat_map`, `map2`, `ap`, `traverse`, `sequence`; Identity, Optional, Result and List instances |
| `fp.effects` | Reader, State and Writer, and transformer stacks | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`; `ask`, `local`, `get`, `put`, `modify`, `tell`, `listen`, `censor`, `run` |
| `fp.callables` | The calling protocols shared by other components | `Unary`, `Binary`, `Thunk`, `as_unary`, `call_once`, `call_repeated` |

## A quick tour

The best way to learn a library is through concrete examples.

### Pipelines and composition

`pipe` calls functions left to right and infers every intermediate type. Importantly, errors
keep their type: here the pipeline raises a `ParseError` as opposed to a generic `Error`.

```mojo
from fp.functions import pipe, flow, partial

@fieldwise_init
struct ParseError(Movable, Writable):
    var text: String

def parse(text: String) raises ParseError -> Int:
    try:
        return atol(text)
    except:
        raise ParseError(text)

def twice(value: Int) -> Int: return value * 2
def label(value: Int) -> String: return "value = " + String(value)
def scale(factor: Int, value: Int) -> Int: return factor * value

def main() raises:
    print(pipe(String("21"), parse, twice, label))   # value = 42
    try:
        _ = pipe(String("abc"), parse, twice, label)
    except error:                                    # a ParseError, not a generic Error
        print("cannot parse:", error.text)           # cannot parse: abc

    var render = flow(twice, label)                  # compose now, call later
    print(render(5))                                 # value = 10
    var triple = partial(scale, 3)                   # bind a prefix of the arguments
    print(triple(7))                                 # 21

    # Alternative piping syntax designed for long chains (> 8 functions) 
    print(piped(String("21")).then(parse).then(twice).then(label).get()) 
```

`pipe` takes up to eight plain functions in one call. For longer chains, or to
use closures without promoting them, chain the stages one call at a time:
`piped(String("21")).then(parse).then(twice).then(label).get()`.

### Lazy iteration

Classic lazy iteration, i.e. pipelines are not executed until a terminal
operation asks for concrete values. Pass a collection with `^` to consume
it, or any iterator such as `range`.

```mojo
from fp.iteration import map, filter, scan_left, collect_list, find

def positive(value: Int) -> Bool: return value > 0
def add(total: Int, value: Int) -> Int: return total + value
def large(value: Int) -> Bool: return value > 10

def main():
    var calls = 0
    def square(value: Int) {mut calls} -> Int:
        calls += 1
        return value * value

    var values: List[Int] = [3, -1, 4, -1, 5]
    var squares = map(square, filter(positive, values^))   # a lazy iterator
    print(calls)                                           # 0: nothing has run yet
    var running = collect_list(scan_left(add, 0, squares^))
    print(running[3], calls)                               # 50 3
    print(find(large, range(100)).value())                 # 11: stops at the first match
```

### Results

Railway Oriented Programming with `Result[Ok, Err]` type. The callback on the opposite branch is never executed.

```mojo
from fp.data import Result, Ok, Err

def parse_age(text: String) -> Result[Int, String]:
    try:
        return Ok(atol(text))
    except:
        return Err("not a number: " + text)

def adult(age: Int) -> Result[Int, String]:
    if age < 18:
        return Err(String("under 18"))
    return Ok(age)

def welcome(age: Int) -> String: return "welcome, age " + String(age)
def refuse(reason: String) -> String: return "refused: " + reason

def main():
    for text in ["42", "12", "old"]:
        print(parse_age(text).flat_map(adult).fold(welcome, refuse))
    # welcome, age 42
    # refused: under 18
    # refused: not a number: old
```

`attempt(f, args...)` turns a raising call into a `Result`, and `raise_on_err`
turns it back, with the original error type both ways.

### Algebraic data and pattern matching

Inductive (recursive) data types, algebraic data types, and pattern matching
on them. A match takes one clause per constructor, either a plain function or
a lambda, whose parameter type determines the handled constructor. We make sure
the matching is exhaustive - omitting a constructor triggers a build error:
`fp.match: constructor ... has no clause that cannot decline`. Recursive fields
are marked with `R` type.

```mojo
import fp
from fp.adt import Data, Cases, Node, Value
from fp.matching import Next

@fieldwise_init
struct Num(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct Add[R: Value](Movable):
    var left: Self.R
    var right: Self.R

@fieldwise_init
struct If[C: Value, B: Value](Movable):
    var cond: Self.C
    var then: Self.B
    var other: Self.B

struct Expr(Data):
    comptime Layer[R: Value] = Cases[Num, Add[R], If[R, R]]

comptime E = Node[Expr]

def evaluate(e: E) -> Int:
    return fp.match(e,
        lambda (n: Num) -> Int: n.value,
        lambda (a: Add[Int]) -> Int: a.left + a.right,       # both sides arrive evaluated
        lambda (c: If[Int, E]) -> Next[E]: Next(c.then if c.cond != 0 else c.other))

def simplify(e: E) -> E:
    return fp.rewrite(e,
        fp.when[lambda (a: Add[E]) -> Bool: a.left == Num(0), lambda (a: Add[E]) -> E: a.right])

def main():
    var zero: E = Num(0)
    var x: E = If(E(Num(1)), E(Add(zero, E(Num(5)))), zero)
    print(evaluate(x))             # 5: the branch not taken is never evaluated
    print(evaluate(simplify(x)))   # 5: 0 + 5 became 5
```

Values are immutable and shared, so they form finite acyclic graphs and every
match ends; a shared value is evaluated once per match. `fp.match` can
optionally take a `context=` for every clause. It can also handle two or three values at once.

A type without recursive fields can be stored in place, without allocation, as
a `Choice[F]`. `Result`, `ControlFlow` and the standard `Optional` are matched
the same way: `fp.match(result, lambda (o: Ok[Int]) -> Int: o.value, lambda (e:
Err[String]) -> Int: -1)`, or `lambda (n: NoneType) -> ...` for an absent
`Optional`.

### Functors, monads and effects

One set of operations works across contexts; you pick the instance explicitly.
`traverse` stops at the first failure. Reader, State and Writer computations are
ordinary values that you compose and then run.

```mojo
from fp.algebra import map, traverse, ListFamily, OptionalFamily
from fp.effects import State, run, get, modify

def positive(value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()

def twice(value: Int) -> Int: return value * 2

def main() raises:
    var good: List[Int] = [1, 2, 3]
    var bad: List[Int] = [1, -2, 3]
    print(Bool(traverse[ListFamily, OptionalFamily](positive, good^)))  # True: every value present
    print(Bool(traverse[ListFamily, OptionalFamily](positive, bad^)))   # False: stops at -2

    # A State computation is an ordinary value until you run it.
    var doubled = map[State[Int]](twice, get[State[Int]]())
    var outcome = run[State[Int]](doubled^, 21)
    print(outcome[0], outcome[1])                                       # 42 21
    print(run[State[Int]](modify[State[Int]](twice), 21)[1])            # 42
```

Transformers stack in either order (`ResultT[State[S], E]` keeps the state on
failure, `StateT[ResultFamily[E], S]` does not), and third-party types can join
by implementing the same traits.

## Getting started

fp_mojo is published in the
[Modular community channel](https://github.com/modular/modular-community). Add the
channel to your [Pixi](https://pixi.sh) project and install the package; it works
with Mojo 1.1.x on Linux x86-64 and macOS arm64:

```toml
# pixi.toml
[workspace]
channels = ["https://conda.modular.com/max", "https://repo.prefix.dev/modular-community", "conda-forge"]
```

```sh
pixi add fp_mojo
pixi run mojo run my_program.mojo          # `from fp.functions import pipe` just works
```

To work from a checkout instead:

```sh
git clone https://github.com/Spellbound-Mojo/fp_mojo.git
cd fp_mojo
pixi install --locked
pixi run mojo run -I src docs/examples/quickstart.mojo   # prints 42
```

From the checkout, point the compiler at the sources, or at a precompiled
package:

```sh
pixi run mojo run -I src path/to/my_program.mojo

pixi run build --format precompiled --output .cache/fp   # writes .cache/fp/fp.mojoc
pixi run mojo run -I .cache/fp path/to/my_program.mojo
```

Import each name from the package that owns it, such as
`from fp.functions import pipe`; the root package `fp` re-exports nothing.

## Documentation

The full documentation is published at
**[spellbound-mojo.github.io/fp_mojo](https://spellbound-mojo.github.io/fp_mojo/)**:
a seven-part tutorial, runnable examples and an API reference generated from the
source. Its sources are in [`docs/content`](docs/content/index.md); to browse them
locally:

```sh
pixi install --locked -e docs
pixi run docs-serve
```

| Start with | For |
|---|---|
| [Tutorial](docs/content/tutorial/pipelines.md) | Seven runnable lessons, from pipelines to a complete configuration processor |
| [Examples](docs/content/examples/index.md) | Every example program, with its output |
| [Ownership and errors](docs/content/start/ownership.md) | How borrowing, moving and failures work across the library |
| [API reference](docs/content/reference/index.md) | Every public name, with its contract |
| [Architecture](docs/content/architecture/overview.md) | How it is built, and why |
| [Support and limitations](docs/content/guides/status.md) | What is covered today, and what is not |

## Status

fp_mojo **1.0.0** is feature-complete for its documented contracts on Mojo
1.1. The allocation-free core also cross-compiles for NVIDIA and AMD GPUs;
running it on GPU hardware is not yet verified. Mojo 1.1 limits that shape the API are listed in
[native boundaries](docs/content/architecture/native-boundaries.md).

## Development

Tests, examples and benchmarks run as one suite of four executables, built in
parallel and run together in about two minutes on four cores. Compile-failure
programs are checked separately:

```sh
pixi run build --format precompiled --output .cache/package-run
pixi run suite --package .cache/package-run          # tests, examples and benchmarks
pixi run compile-fail --package .cache/package-run   # programs that must not compile
pixi run -e docs docs-check
```

Benchmarks against hand-written loops are printed with every suite run as
diagnostics. See the [development guide](docs/content/contributing/development.md)
for the full set of gates, the compile-time budget and the project's working
rules.

## License

Apache License 2.0; see [LICENSE](LICENSE).
