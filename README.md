# FP Mojo

FP Mojo provides native, high-performance functional programming foundations for
[Mojo](https://modular.com/mojo). Compose fluent pipelines, iterate lazily over
collections with zero intermediate allocations, handle failures predictably with
typed `Result` values, and build expressive algebraic and inductive data types with
compile-time exhaustive pattern matching. Functions and closures retain their
native argument conventions (`var`, `ref`, `mut`) and exact error types.

For side effects and concurrency, FP Mojo brings pure synchronous IO, scoped
resource safety, and structured asynchronous concurrency inspired by
[Cats](https://github.com/typelevel/cats) and [Cats Effect](https://github.com/typelevel/cats-effect)—reimagined
around Mojo's ownership model and bare-metal execution speed.

FP Mojo 1.0.2 targets **Mojo 1.2.0**, with unified pipelines, richer error
recovery and the async runtime. FP Mojo 1.0.0 and 1.0.1 target Mojo 1.1.0; see
[installation](docs/content/start/installation.md).

![Mojo 1.2.0](https://img.shields.io/badge/Mojo-1.2.0-orange)
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
    return fold_left(map(filter(values^, positive), square), 0, add)

def report(total: Int) -> String: return "sum of squares = " + String(total)

def main():
    var values: List[Int] = [3, -1, 4, -1, 5]
    print(pipe(values^, sum_of_squares, report))   # sum of squares = 50
```

`filter` keeps 3, 4 and 5, `map` squares them, and `fold_left` adds the
squares to 50. Nothing is copied into an intermediate list: `fold_left` pulls
one value at a time through `map` and `filter`.

## What you get

- **Native values and zero-cost abstractions.** Use standard Mojo structs,
  tuples, `List`, `Optional`, and `Variant` with ordinary functions and closures.
  Borrowing (`ref`), mutation (`mut`), and moves (`var`, `^`) are tracked at
  compile time without runtime wrapping overhead.
- **Unified pipelines and function composition.** Compose functions with `pipeline`
  and `pipe`, adapt signatures with `partial` and `flip`, and build reusable
  transforms with `flow`. Intermediate types and error channels infer automatically.
- **Lazy iteration.** Zero-allocation iterator pipelines (`map`, `filter`,
  `fold_left`, `scan_left`, `fold_until`, `collect_list`) pull values on demand
  without intermediate buffer allocation.
- **Typed errors and principled recovery.** A callback that `raises ParseError`
  propagates typed errors without generic exception degradation. Or preserve errors
  as values with `Result[T, E]`, sequence with `flat_map`, recover conditionally
  with `recover_if`, or observe failures with `flat_tap_err`.
- **Exhaustive compile-time pattern matching.** `fp.match` guarantees at compile time
  that every constructor of an algebraic data type (`Choice`) or inductive recursive tree
  (`Node`) is handled, rejecting missing cases before runtime.
- **Structural recursion without stack overflows.** Traverse inductive data structures
  millions of levels deep with `Node[F]` and `fp.match` via an explicit evaluation stack.
- **Category-theoretic foundations.** Functor, Filterable, Applicative, Monad, and
  Traversable instances for collections and effects, alongside Reader, State, Writer,
  and monad transformers (`ResultT`, `StateT`).
- **Pure IO and scoped resources.** Defer computations with `delay`, guarantee
  safe acquisition and release with `Resource` scopes in reverse order of creation,
  and run with `run_io()`, preserving error order in structured `Outcome` values.
- **Structured async concurrency.** Pure-Mojo `IO[T, E]` coordinates lightweight
  fibers, concurrent execution (`both`), racing (`race`, `race_pair`), timeouts,
  and dynamic background tasks (`background`, `Supervisor`). Coordinate fibers with
  `Deferred`, `Ref`, `Queue`, and `Semaphore`.
- **Deterministic testing with TestControl.** Control virtual time, advance
  scheduled fibers step by step, explore scheduling interleavings, and replay test
  runs deterministically without wall-clock sleeps.

## Choose a package

| Package | What it gives you | Highlights |
|---|---|---|
| `fp.functions` | Pipelines and composition | `pipeline`, `pipe`, `flow`, `compose`, `flip`, `partial`, `identity` |
| `fp.combinators` | Ordinary iterator operations shared with fluent pipelines | `map`, `filter`, `fold_left` |
| `fp.iteration` | Lazy adapters and terminal folds over iterators and owned collections | `map`, `filter`, `filter_map`, `flat_map`, `flatten`, `scan_left`, `fold_left`, `fold_until`, `reduce`, `find`, `any`, `all`, `collect_list` |
| `fp.control` | Loops as expressions | `while_loop`, `fori_loop`, carry/output `scan` |
| `fp.data` | Typed results and error bridges | `Result` with `map`, `flat_map`, `map_err`, `or_else`, `fold`; `attempt`, `raise_on_err`, `collect_results`, `ControlFlow` |
| `fp.adt` | Algebraic and inductive data types from your own structs | `Data`, `Cases`; `Node` (shared, recursive) and `Choice` (stored in place) |
| `fp.matching` | Pattern matching | `fp.match` (a `Node`, `Choice`, `Result` or `Optional`, a context, or several values), `fp.rewrite`, `fp.when`, `Next` |
| `fp.algebra` | Functor, Filterable, Applicative, Monad, Traversable and Monoid | `map`, `filter`, `pure`, `flat_map`, `tail_rec_m`, `map2`, `ap`, `traverse`, `sequence`; Identity, Optional, Result and List instances |
| `fp.effects` | Reader, State, Writer, monad transformers, synchronous IO and resource scopes | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`, `IO`, `Resource`, `IOResource`, `Outcome`; `delay`, `run_io`, `guarantee`, `fold_outcome` |
| `fp.effects.async_runtime` | Cooperative async IO and structured concurrency (preview) | `IO`, `Fiber`, `background`, `Supervisor`, `Resource`, `Driver`, `TestControl`, `Runtime`, `Deferred`, `Queue`, `Semaphore`; `both`, `race`, `sleep`, `timeout_to` |
| `fp.effects.async_runtime.protocols` | Extension contracts for custom async leaves lifted into `IO` and scoped borrowing | `Machine`, `ScopedMachine`, `CleanupMachine`, `Context`, `Step`, `Wait`, `Signal` |
| `fp.callables` | Calling protocols shared by other components | `Unary`, `Binary`, `Thunk`, `as_unary`, `call_once`, `call_repeated` |

## See it in action

### Chain functions; errors keep their type

`pipe` applies functions from left to right and infers every intermediate type.
If a stage raises, the pipeline stops and propagates its error. In this example,
the caller catches a `ParseError` and can read the text that failed to parse.

```mojo
from fp.functions import pipe, pipeline, flow, partial

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

    # One stage per call, with no limit on the number of stages
    print(pipeline(String("21")).then(parse).then(twice).then(label).get())   # value = 42
```

`"21"` parses to 21, doubles to 42 and prints as `value = 42`. With `"abc"`,
`parse` raises, `twice` and `label` never run, and the `except` block reads the
`ParseError`'s text. `pipe` takes up to eight plain functions in one call; for
longer chains, or to combine functions, closures and values fluently, use
`pipeline(...).then(...)`, as on the last line.

### Iterate lazily

`map`, `filter` and `scan_left` build iterators that run nothing until a
terminal operation such as `collect_list` or `find` pulls values. Pass a
collection with `^` to consume it, or any iterator such as `range`.

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
    var squares = map(filter(values^, positive), square)   # a lazy iterator
    print(calls)                                           # 0: nothing has run yet
    var running = collect_list(scan_left(squares^, 0, add))
    print(running[3], calls)                               # 50 3
    print(find(range(100), large).value())                 # 11: stops at the first match
```

Building `squares` calls nothing, so `calls` is still 0. Collecting the running
totals squares 3, 4 and 5, once each, and the totals end at 50. `find` pulls
`range(100)` only up to 11.

### Run only the active branch of a Result

`Result[T, E]` is a sum type with two constructors: `Ok[T]` for success and
`Err[E]` for failure. `flat_map` sequences computations that return a `Result`,
stopping at the first `Err`. `fold` handles either case to produce one result.

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

`"12"` parses, so `adult` runs and returns `Err("under 18")`, and `fold` calls
`refuse`. `"old"` fails to parse, so `adult` never runs. `attempt(f, args...)`
turns a raising call into a `Result`, and `raise_on_err` turns it back, with
the original error type both ways.

### Match every constructor of your own data type

Declare an algebraic data type by listing its constructors as structs in
`Cases`. To define an inductive type, such as an expression tree, mark its
recursive fields with the parameter `R`. Each match clause is a plain function
or a lambda whose parameter type selects the constructor it handles. The match
must cover every constructor; otherwise the compiler reports
`fp.match: constructor ... has no clause that cannot decline`.

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

`x` is `If(1, 0 + 5, 0)`. The `Add[Int]` clause receives both sides already
evaluated, and the `If` clause returns `Next` with the branch it takes, so the
other branch is never evaluated. `simplify` rewrites `0 + 5` to `5`, and both
calls print 5.

`Node` values are immutable and can share subexpressions, forming finite acyclic
graphs. With the `Int` result used here, each shared value is evaluated once per
match. `fp.match` can also pass a `context=` to every clause and match two or
three values at once.

A type without recursive fields can be stored in place, without allocation, as
a `Choice[F]`. `Result`, `ControlFlow` and the standard `Optional` are matched
the same way: `fp.match(result, lambda (o: Ok[Int]) -> Int: o.value, lambda (e:
Err[String]) -> Int: -1)`, or `lambda (n: NoneType) -> ...` for an absent
`Optional`.

### Use one set of operations across contexts

Functor, Applicative, Monad and Traversable instances let you use `map`,
`flat_map` and `traverse` with `Optional`, `Result`, `List` and the effect types.
Select the instance at each call. `traverse` applies a computation to each element and
collects the results, stopping at the first failure or absence. Reader, State
and Writer let you compose computations that read an environment, pass state
between steps or accumulate a log.

```mojo
from fp.algebra import map, traverse
from fp.effects import State, run, get, modify

def positive(value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()

def twice(value: Int) -> Int: return value * 2

def main() raises:
    var good: List[Int] = [1, 2, 3]
    var bad: List[Int] = [1, -2, 3]
    print(Bool(traverse(good^, positive)))  # True: every value present
    print(Bool(traverse(bad^, positive)))   # False: stops at -2

    # A State computation is an ordinary value until you run it.
    var doubled = map[State[Int]](get[State[Int]](), twice)
    var outcome = run[State[Int]](doubled^, 21)
    print(outcome[0], outcome[1])                                       # 42 21
    print(run[State[Int]](modify[State[Int]](twice), 21)[1])            # 42
```

`doubled` reads the state and doubles it, so running it from 21 returns the
value 42 with the state still 21. `modify` doubles the state itself, so the
final state is 42.

Monad transformers combine these effects. Their order determines what survives
a failure: `ResultT[State[S], E]` keeps the state, while
`StateT[ResultFamily[E], S]` returns only the error. Third-party types can
provide instances by implementing the same traits.

### Defer IO and keep cleanup in scope

`delay` stores a callback without running it. `pipeline` selects the IO family
and composes the work; `.run_io()` consumes it and returns an `Outcome`.
`guarantee` runs its finalizer after an entered body, including cancellation.
These examples use the Mojo 1.2.0 `nightly` checkout; see
[getting started](#getting-started).

```mojo
from fp.functions import pipeline
from fp.effects import delay, canceled

def read_number() -> Int:
    print("read")
    return 21

def twice(value: Int) -> Int:
    return value * 2

def finish():
    print("finalize")

def main():
    var program = pipeline(delay[Error](read_number)).map(twice).guarantee(delay[Error](finish))
    print("program ready")
    var outcome = program^.run_io()
    if outcome:
        var result = outcome.take()
        try:
            print("value:", result^.raise_on_err())
        except failure:
            print("errors:", len(failure.errors))
    var cancellation = pipeline(canceled[Error]()).guarantee(delay[Error](finish)).run_io()
    print("canceled:", not cancellation)
```

This prints `program ready`, `read`, `finalize`, `value: 42`, `finalize`, then
`canceled: True`. Construction performs no work, and both entered programs
finalize. The [runnable example](docs/examples/io_execution.mojo) is also part
of the documentation checks.

For acquisition and release, use native `resource` scopes or effectful
`resource_io` scopes. Dependent resources release in reverse acquisition order;
cleanup failures are retained alongside the original failure and cancellation
state. See [IO and finalization](docs/content/reference/effects.md#io-cancellation-and-finalization)
and [effectful resources](docs/content/reference/effects.md#effectful-resources).

### Sequence asynchronous work

An async `IO` uses the same `pipeline(...).map(...).flat_map(...)` style.
`run` drives a self-contained program to completion, and `fold_outcome` handles
success, the complete failure, or cancellation. An `IO` runs once; build a
fresh one to repeat work.

```mojo
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run
from fp.functions import pipeline


def next_value(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 2)


def initial() -> Int:
    return 40


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var program = pipeline(IO[Int, Int].delay(initial)).flat_map(next_value).get()
    print(fold_outcome(run(program^), success, failure, canceled))
```

The [runnable example](docs/examples/async_sequencing.mojo) prints `42`.
`flat_map` sequences asynchronous steps in constant native stack without call-stack
growth, supporting deep recursion through `IO.defer` and loops with `tail_rec_m`.
Concurrent children combine via `.both(...)`, race with `.race(...)`, and clean up
dependently under cancellation and timeouts.

Key async capabilities on `nightly`:

- **Structured concurrency**: Child fibers started with `.both()` or `Supervisor`
  remain owned; when a scope closes, uncompleted child fibers are automatically
  cancelled and drained before the parent finishes.
- **Dynamic fibers & background work**: Start detached work with `background`
  or `Supervisor`, obtaining typed fiber handles for joining or cancellation.
- **Blocking offload**: Safely run blocking system calls without starving
  worker threads using `IO.blocking(...)` or `IO.interruptible(...)` with a `BlockingPool`.
- **Coordination primitives**: Synchronize fibers using `Deferred`, `Ref`,
  `Queue`, and `Semaphore`.
- **Deterministic virtual time**: Test asynchronous interactions with `TestControl`—advancing
  time instantly without wall-clock sleep and deterministically exploring scheduling orders.

The [async guide](docs/content/guides/async-runtime.md) includes runnable
examples for fibers, coordination, timeouts, blocking offload, and Cats Effect
concept mapping. The multi-threaded work-stealing engine targets 64-bit Linux;
deterministic `TestControl` and core effects run across macOS and Linux.

## Getting started

FP Mojo is published as `fp_mojo` in the
[Modular community channel](https://github.com/modular/modular-community). Add
the channel to your [Pixi](https://pixi.sh) project and install the package.
FP Mojo 1.0.2 requires Mojo 1.2.0:

```toml
# pixi.toml
[workspace]
channels = ["https://conda.modular.com/max", "https://repo.prefix.dev/modular-community", "conda-forge"]
```

```sh
pixi add fp_mojo "mojo==1.2.0"
```

Save [quickstart.mojo](docs/examples/quickstart.mojo) beside your project's
`pixi.toml`, then run it:

```sh
pixi run mojo run quickstart.mojo          # prints 42; no -I flag needed
```

For a new project, the [installation guide](docs/content/start/installation.md)
walks through creating the environment, saving the program and running it.

To work from source, clone the repository. The `nightly` branch is the
development branch and pins Mojo 1.2.0:

```sh
git clone --branch nightly https://github.com/Spellbound-Mojo/fp_mojo.git
cd fp_mojo
pixi install --locked
pixi run mojo run -I src docs/examples/quickstart.mojo   # prints 42
```

On Linux x86-64, run the async example from that checkout:

```sh
pixi run mojo run -I src docs/examples/async_sequencing.mojo   # prints 42
```

From the checkout, point the compiler at the sources, or at a precompiled
package:

```sh
pixi run mojo run -I src path/to/my_program.mojo

pixi run build --format precompiled --output .cache/fp   # writes .cache/fp/fp.mojoc
pixi run mojo run -I .cache/fp path/to/my_program.mojo
```

Import each name from the package that owns it, such as
`from fp.functions import pipe`. The root package `fp` re-exports only `match`,
`rewrite` and `when`, so `import fp` is enough to write `fp.match(...)`.

## Read the documentation

The documentation is published at
[spellbound-mojo.github.io/fp_mojo](https://spellbound-mojo.github.io/fp_mojo/):
a nine-part tutorial, runnable examples and an API reference generated from the
source. Its sources are in [`docs/content`](docs/content/index.md); to browse
them locally:

```sh
pixi install --locked -e docs
pixi run docs-serve
```

| Start with | For |
|---|---|
| [Tutorial](docs/content/tutorial/pipelines.md) | Nine runnable lessons covering pipelines, data types, a configuration processor, algebra and effects |
| [Algebra](docs/content/tutorial/algebra.md) | When to use mapping, applicative combination, monadic bind and traversal |
| [Effects](docs/content/tutorial/effects.md) | Reader, State and Writer before combining them with monad transformers |
| [IO and resources](docs/content/reference/effects.md#io-cancellation-and-finalization) | Deferred execution, outcomes, cancellation, finalizers and effectful resource scopes |
| [Async runtime](docs/content/guides/async-runtime.md) | Typed sequencing, iterative loops, structured children, timers, callbacks and host integration |
| [Async API reference](docs/content/reference/effects.async_runtime.md) | Application operations and their ownership and cancellation contracts |
| [Examples](docs/content/examples/index.md) | Every example program, with its output |
| [Ownership and errors](docs/content/start/ownership.md) | How borrowing, moving and failures work across the library |
| [API reference](docs/content/reference/index.md) | Every public name, with its contract |
| [Architecture](docs/content/architecture/overview.md) | How it is built, and why |
| [Support and limitations](docs/content/guides/status.md) | What is covered today, and what is not |

## Status & Compatibility

- **Compiler & Toolchain**: FP Mojo 1.0.2 and the `nightly` branch target **Mojo 1.2.0**. FP Mojo 1.0.0 and 1.0.1 target Mojo 1.1.0.
- **Platform Support**:
  - **Linux x86-64**: Complete library support, including the multi-threaded work-stealing async runtime and POSIX driver.
  - **macOS arm64**: Core library support (pipelines, iteration, ADTs, pattern matching, algebra, synchronous effects, and deterministic `TestControl` virtual-time async testing).
- **Architecture & Boundaries**: See [support and limitations](docs/content/guides/status.md) and [native Mojo boundaries](docs/content/architecture/native-boundaries.md) for compiler constraints shaping the API.

## Development & Verification

To build and verify the library locally through Pixi:

```sh
pixi run build --format precompiled --output .cache/package-run
pixi run suite --package .cache/package-run          # tests, examples and benchmarks
pixi run compile-fail --package .cache/package-run   # compile-rejection verification
pixi run -e docs docs-check                         # documentation integrity checks
```

For contribution rules, benchmark harnesses, and coding standards, see the [development guide](docs/content/contributing/development.md).

## License

Apache License 2.0; see [LICENSE](LICENSE).
