# FP Mojo

FP Mojo is a functional programming library for Mojo. You can compose functions
into pipelines, map, filter, and fold over collections, handle failures with
typed `Result` values, and define algebraic and inductive data types from your
own structs. Pattern matching checks that every constructor is covered at
compile time. Functions and closures keep their native ownership conventions
and error types. Deferred IO, scoped resources and cooperative async tasks let
you compose effectful work with the same pipeline and algebra operations.

The API draws on [Cats](https://github.com/typelevel/cats) and
[Cats Effect](https://github.com/typelevel/cats-effect), using snake_case
operations and Mojo's native types and ownership.

The `nightly` checkout pins Mojo 1.2.0. The published FP Mojo 1.0.0 package
uses Mojo 1.1.0; see [installation](docs/content/start/installation.md).
The verified Linux Mojo 1.2 checkpoint passes the full positive and rejection
suites, package imports and executable documentation. Selected API migration
continues; legacy invalid-call inference and platform limits remain documented
in the [compatibility inventory](docs/content/guides/compatibility.md).

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
    return fold_left(add, 0, map(square, filter(positive, values^)))

def report(total: Int) -> String: return "sum of squares = " + String(total)

def main():
    var values: List[Int] = [3, -1, 4, -1, 5]
    print(pipe(values^, sum_of_squares, report))   # sum of squares = 50
```

`filter` keeps 3, 4 and 5, `map` squares them, and `fold_left` adds the
squares to 50. Nothing is copied into an intermediate list: `fold_left` pulls
one value at a time through `map` and `filter`.

## What you get

- **Native values and callbacks.** Use `List`, `Optional`, `Variant`, tuples
  and your own structs with ordinary Mojo functions and closures. Their types
  remain known to the compiler through composition.
- **Ownership and borrowing.** Operations support move-only values and borrowed
  views through Mojo's `var`, read and `mut` conventions. References keep their
  origins, tying borrowed payloads to their owners.
- **Typed errors.** A callback that `raises ParseError` makes the pipeline, fold
  or match raise `ParseError`. A stored `Err` remains a value until you
  explicitly raise it with `raise_on_err`.
- **IO and resources.** Describe deferred work, compose it with `map` and
  `flat_map`, and execute it with `run_io`. Resource scopes and finalizers
  retain cleanup on success, failure and cooperative cancellation, preserving
  ordered errors in `Outcome`.
- **Structured async.** The pure-Mojo runtime follows Cats Effect: an
  `IO[T, E]` sequences work in constant native stack on one host thread.
  Combine concurrent children, race work, wait on timers or callbacks, and
  coordinate through queues and semaphores. Entered child tasks remain owned
  until their work and cleanup finish.
- **Exhaustive pattern matching.** The compiler rejects a match that misses a
  constructor or includes an unreachable clause. It also checks the types
  between pipeline stages and names a stage whose input does not fit.
- **Structural recursion.** Write clauses for the constructors of an inductive
  data type, and `fp.match` evaluates recursive fields with an explicit stack.
  A value a million levels deep can be matched without overflowing the native
  stack. Matching traverses finite, acyclic values; code inside a clause follows
  the usual rules for Mojo functions.

## Choose a package

| Package | What it gives you | Highlights |
|---|---|---|
| `fp.functions` | Pipelines and composition | `pipeline`, `pipe`, `piped`, `flow`, `compose`, `flip`, `partial`, `identity` |
| `fp.combinators` | Ordinary iterator operations shared with fluent pipelines | `map`, `filter`, `fold_left` |
| `fp.iteration` | Lazy adapters and terminal folds over iterators and owned collections | `map`, `filter`, `filter_map`, `flat_map`, `flatten`, `scan_left`, `fold_left`, `fold_until`, `reduce`, `find`, `any`, `all`, `collect_list` |
| `fp.control` | Loops as expressions | `while_loop`, `fori_loop`, carry/output `scan` |
| `fp.data` | Typed results and error bridges | `Result` with `map`, `flat_map`, `map_err`, `or_else`, `fold`; `attempt`, `raise_on_err`, `collect_results`, `ControlFlow` |
| `fp.adt` | Algebraic and inductive data types from your own structs | `Data`, `Cases`; `Node` (shared, recursive) and `Choice` (stored in place) |
| `fp.matching` | Pattern matching | `fp.match` (a `Node`, `Choice`, `Result` or `Optional`, a context, or several values), `fp.rewrite`, `fp.when`, `Next` |
| `fp.algebra` | Functor, Filterable, Applicative, Monad, Traversable and Monoid | `map`, `filter`, `pure`, `flat_map`, `tail_rec_m`, `map2`, `ap`, `traverse`, `sequence`; Identity, Optional, Result and List instances |
| `fp.effects` | Reader, State, Writer, monad transformers, synchronous IO and resource scopes | `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`, `IO`, `Resource`, `IOResource`, `Outcome`; `delay`, `run_io`, `guarantee`, `fold_outcome` |
| `fp.effects.async_runtime` | Cooperative async IO and structured concurrency (preview) | `IO`, `Async`, `Resource`, `Driver`, `Deferred`, `Queue`, `Semaphore`; `IO.both`, `IO.race`, `IO.sleep`, `IO.timeout_to`, `IO.async`, `IO.eval_io` |
| `fp.effects.async_runtime.protocols` | Extension contracts for custom async leaves lifted into `IO` and scoped borrowing | `Machine`, `ScopedMachine`, `CleanupMachine`, `Context`, `Step`, `Wait`, `Signal` |
| `fp.callables` | The calling protocols shared by other components | `Unary`, `Binary`, `Thunk`, `as_unary`, `call_once`, `call_repeated` |

## See it in action

### Chain functions; errors keep their type

`pipe` applies functions from left to right and infers every intermediate type.
If a stage raises, the pipeline stops and propagates its error. In this example,
the caller catches a `ParseError` and can read the text that failed to parse.

```mojo
from fp.functions import pipe, piped, flow, partial

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
    print(piped(String("21")).then(parse).then(twice).then(label).get())   # value = 42
```

`"21"` parses to 21, doubles to 42 and prints as `value = 42`. With `"abc"`,
`parse` raises, `twice` and `label` never run, and the `except` block reads the
`ParseError`'s text. `pipe` takes up to eight plain functions in one call; for
longer chains, or to use closures without promoting them with `as_unary`, use
`piped(...).then(...)`, as on the last line.

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
    var squares = map(square, filter(positive, values^))   # a lazy iterator
    print(calls)                                           # 0: nothing has run yet
    var running = collect_list(scan_left(add, 0, squares^))
    print(running[3], calls)                               # 50 3
    print(find(large, range(100)).value())                 # 11: stops at the first match
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
`flat_map` sequences work; `both` owns concurrent children. Chains, recursion
through `IO.defer`, and `tail_rec_m` loops of any length run in constant native
stack. Resources, races and timeouts retain ownership through cancellation and
cleanup.
Checked `Duration` values and opaque `Instant` timestamps support system and
manual clocks.

For host integration, use `Driver`: poll until complete, then consume
`finish()`. After `request_cancel()`, continue polling until cleanup finishes.
Timeouts also wait for cleanup; they do not impose a hard return deadline.
`IO.delay` and `IO.eval_io` run synchronous callbacks inside a poll, so callbacks
must return promptly. Blocking IO is not offloaded.

The [async guide](docs/content/guides/async-runtime.md) includes runnable
resource, callback, timeout and host-cancellation examples, plus a Cats Effect
mapping. The preview is qualified on Linux x86-64 with Mojo 1.2.0; GPU execution
and completion delivery from foreign threads are not implemented.

## Getting started

FP Mojo is published as `fp_mojo` in the
[Modular community channel](https://github.com/modular/modular-community). Add
the channel to your [Pixi](https://pixi.sh) project and install the package. It
is verified with Mojo 1.1.0 on Linux x86-64 and macOS arm64:

```toml
# pixi.toml
[workspace]
channels = ["https://conda.modular.com/max", "https://repo.prefix.dev/modular-community", "conda-forge"]
```

```sh
pixi add fp_mojo "mojo==1.1.0"
```

Save [quickstart.mojo](docs/examples/quickstart.mojo) beside your project's
`pixi.toml`, then run it:

```sh
pixi run mojo run quickstart.mojo          # prints 42; no -I flag needed
```

For a new project, the [installation guide](docs/content/start/installation.md)
walks through creating the environment, saving the program and running it.

For the IO and async features above, use the `nightly` source checkout with
Mojo 1.2.0. These additions are not part of the published 1.0.0 package:

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

## Status

The `nightly` checkout targets Mojo 1.2.0; published FP Mojo 1.0.0 targets
Mojo 1.1. The async runtime remains an opt-in preview qualified on Linux x86-64.
Source/package checks at O0/O3 and the completed
[overnight qualification](docs/content/architecture/async-qualification.md#overnight-results)
cover sustained execution, retained storage and local performance measurements.

The allocation-free core was also cross-compiled on Mojo 1.1 for NVIDIA and AMD
GPUs; execution on GPU hardware has not yet been verified. That core compilation
coverage does not extend to IO or the host async runtime. See
[support and limitations](docs/content/guides/status.md) for supported uses and
[native boundaries](docs/content/architecture/native-boundaries.md) for the
compiler constraints that shape the API and the Mojo 1.2 migration.

## Development

Tests, examples and benchmarks run as one suite of four executables, built in
parallel. Build time depends on the toolchain, cache and host load.
Compile-failure programs are checked separately:

```sh
pixi run build --format precompiled --output .cache/package-run
pixi run suite --package .cache/package-run          # tests, examples and benchmarks
pixi run compile-fail --package .cache/package-run   # programs that must not compile
pixi run -e docs docs-check
```

Every suite run also prints benchmarks against hand-written loops, as
diagnostics. See the [development guide](docs/content/contributing/development.md)
for the full set of gates, the compile-time budget and the project's working
rules. Focused async checks and overnight stress runs use the separate
[async qualification procedure](docs/content/architecture/async-qualification.md).

## License

Apache License 2.0; see [LICENSE](LICENSE).
