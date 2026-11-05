# FP Mojo

FP Mojo is a functional programming toolkit and structured asynchronous runtime
for Mojo. It combines composable functional abstractions—fluent pipelines,
zero-allocation lazy iterators, pure monadic effects, and compile-time exhaustive
pattern matching—with a high-performance concurrency engine. Programs coordinate
asynchronous I/O through lightweight cancelable fibers, cooperative work-stealing
scheduling, and deterministic virtual-time testing, all while preserving Mojo's
native argument conventions (`var`, `ref`, `mut`), explicit memory ownership,
and exact compiler error types without runtime overhead.

FP Mojo 1.0.2 targets **Mojo 1.2.0**, qualified on **64-bit Linux** and **macOS arm64**.
(FP Mojo 1.0.0 and 1.0.1 target Mojo 1.1.0; see [installation](docs/content/start/installation.md)).

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

`filter` retains 3, 4, and 5; `map` squares each element; and `fold_left` accumulates
the total to 50. Execution is strictly lazy: elements stream one at a time through `map`
and `filter` as `fold_left` requests them, without intermediate heap allocations.

## Core capabilities

- **Pipelines & function composition.** Build fluent data-transformation pipelines with `pipeline`
  and `pipe`, adapt signatures with `partial` and `flip`, and construct reusable transforms
  with `flow`. Intermediate carrier types and error channels infer automatically.
- **Pattern matching & algebraic data types.** Model domain structures with stack-allocated
  sum types (`Choice`) and recursive graph trees (`Node`). Verify branch coverage safely
  via compile-time exhaustive pattern matching (`fp.match`) and expressive guards (`fp.when`).
- **Pure effects & transformers.** Manage application dependencies, state transitions,
  and structured logs with `Reader`, `State`, and `Writer`. Stack independent effect layers
  predictably using composable monad transformers (`ResultT`, `StateT`, `WriterT`).
- **Structured async concurrency.** Pure-Mojo `IO[T, E]` coordinates lightweight cancelable
  fibers, parallel combinations (`both`), racing (`race`, `race_pair`), timeouts, and supervised
  background tasks (`background`, `Supervisor`). Synchronize fibers safely with `Deferred`,
  `Ref`, `Queue`, and `Semaphore`.
- **Zero-allocation lazy streaming.** Iterator adapters (`map`, `filter`, `scan_left`,
  `fold_until`, `collect_list`) pull elements on demand without materializing intermediate
  collections or boxing callbacks.
- **Typed errors & principled recovery.** Propagate native raised errors without exception
  degradation, or retain failures as values with `Result[T, E]`. Chain operations with `flat_map`,
  recover conditionally with `recover_if`, or inspect failures with `flat_tap_err`.
- **Structural recursion without stack overflows.** Traverse inductive data structures
  millions of levels deep with `Node[F]` and `fp.match` via an explicit heap-safe evaluation stack.
- **Deterministic testing with TestControl.** Control virtual time, advance scheduled
  fibers cooperatively step by step, explore scheduling interleavings, and verify concurrent
  interactions deterministically without wall-clock sleeps.

## Package architecture

| Package | Responsibility | Primary APIs |
|---|---|---|
| `fp.functions` | Eager pipelines, function composition, and partial application | `pipeline`, `pipe`, `flow`, `compose`, `flip`, `partial`, `identity` |
| `fp.combinators` | Iterator operations shared across collections and pipelines | `map`, `filter`, `fold_left` |
| `fp.iteration` | Zero-allocation lazy adapters and terminal folds over iterators and collections | `map`, `filter`, `filter_map`, `flat_map`, `flatten`, `scan_left`, `fold_left`, `fold_until`, `reduce`, `find`, `any`, `all`, `collect_list` |
| `fp.control` | Functional loop expressions and scans | `while_loop`, `fori_loop`, `scan` |
| `fp.data` | Typed algebraic results and error channels | `Result`, `Ok`, `Err`, `ControlFlow`, `Ior`, `NonEmptyList`, `attempt`, `raise_on_err`, `collect_results` |
| `fp.adt` | In-place and recursive algebraic data types | `Data`, `Cases`, `Node` (shared recursive graph), `Choice` (stack-allocated variant) |
| `fp.matching` | Exhaustive pattern matching and term rewriting | `fp.match`, `fp.rewrite`, `fp.when`, `Next`, `Guarded` |
| `fp.algebra` | Category-theoretic typeclasses and instances | `Functor`, `Filterable`, `Applicative`, `Monad`, `Traversable`, `Semigroup`, `Monoid`, `tail_rec_m`, `map2`, `ap`, `traverse`, `sequence` |
| `fp.effects` | Synchronous IO, resource scopes, and monad transformers | `Reader`, `State`, `Writer`, `ReaderT`, `StateT`, `WriterT`, `OptionalT`, `ResultT`, `IO`, `Resource`, `Outcome`, `delay`, `run_io`, `guarantee` |
| `fp.effects.async_runtime` | Structured asynchronous runtime and concurrency primitives | `IO`, `Fiber`, `background`, `Supervisor`, `Resource`, `Driver`, `TestControl`, `Runtime`, `Deferred`, `Queue`, `Semaphore`, `both`, `race`, `sleep`, `timeout_to` |
| `fp.effects.async_runtime.protocols` | Extension protocols for custom async leaves and scoped borrowing | `Machine`, `ScopedMachine`, `CleanupMachine`, `Context`, `Step`, `Wait`, `Signal` |
| `fp.callables` | Fixed-arity callable protocols and receiver dispatch | `Unary`, `Binary`, `Thunk`, `BorrowCallable`, `as_unary`, `as_binary`, `call_once`, `call_repeated` |

## Technical walkthroughs

### Eager function composition with exact error propagation

`pipe` applies functions from left to right and infers every intermediate type.
If a stage raises, execution stops immediately and propagates the exact typed error.
In this example, the caller catches a distinct `ParseError`, reading the invalid input
without stringly-typed exception degradation:

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

### Zero-allocation lazy streaming iteration

`map`, `filter`, and `scan_left` construct composable iterator pipelines that perform
no work until a terminal consumer (`collect_list`, `find`, `fold_left`) pulls elements.
Pass collections with `^` to transfer ownership, or borrow an iterator directly:

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

### Algebraic error handling with Result

`Result[T, E]` is a stack-allocated sum type representing either successful `Ok[T]`
or failure `Err[E]`. `flat_map` chains dependent operations, short-circuiting on the first
`Err`. `fold` handles both branches exhaustively to extract a unified output:

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

### Independent error accumulation with par_map_n

While `flat_map` short-circuits on the first error, `par_map_n` aggregates failures across
independent validation checks. When all validations succeed, it applies a combining function;
if any fail, all accumulated errors are preserved:

```mojo
from fp.data import Result, Ok, Err
from fp.functions import pipeline

comptime Checked = Result[Int, List[String]]

def positive(value: Int) -> Checked:
    if value <= 0:
        return Err(List[String]([String(value) + " must be positive"]))
    return Ok(value)

def total(a: Int, b: Int, c: Int) -> Int:
    return a + b + c

def main():
    # Both negative inputs fail independently; par_map_n reports all errors together
    var invalid = pipeline(positive(-2)).par_map_n((positive(3), positive(-4)), total).get()
    if invalid.is_err():
        var errors = invalid^.swap().to_optional()
        for error in errors.value():
            print("validation error:", error)
        # validation error: -2 must be positive
        # validation error: -4 must be positive
```

### Compile-time exhaustive pattern matching

Declare algebraic data types by listing constructor structs in `Cases`. For inductive
recursive types (such as AST expression trees), parameterize recursive positions with `R`.
Match clauses are plain functions or non-capturing lambdas whose parameter types select
the constructor. The compiler verifies exhaustiveness, rejecting missing branches at build time:

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

### Unified algebraic operations and monad transformers

`Functor`, `Applicative`, `Monad`, and `Traversable` instances provide generic operations
(`map`, `flat_map`, `traverse`) across standard collections (`Optional`, `Result`, `List`)
and effectful carriers. Select the instance at each call site. `traverse` applies a computation
to each element and collects the results, short-circuiting on the first failure or absence.
`Reader`, `State`, and `Writer` compose computations that access an environment, evolve state,
or accumulate an ordered log:

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

### Pure IO and scoped resource finalization

`delay` reifies side-effectful computations into deferred values without executing them.
`pipeline` chains IO operations fluently, and `.run_io()` evaluates the program, returning
a structured `Outcome`. `guarantee` ensures cleanup programs execute on success, failure,
or cancellation. Resources manage acquisition and deterministic teardown in reverse order:

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

### Structured asynchronous concurrency with fibers

Async `IO[T, E]` sequences asynchronous programs in constant native stack without recursive
stack growth. `run` drives programs to completion on a work-stealing pool or single-thread
executor, and `fold_outcome` handles success, structured failure, or cancellation. Concurrent
children join with `.both()`, compete with `.race()`, and drain uncompleted work automatically
upon scope termination:

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

Key runtime guarantees:

- **Structured concurrency**: Child fibers spawned via `.both()` or `Supervisor`
  remain owned; when an enclosing scope completes or cancels, uncompleted child fibers
  are automatically cancelled and drained before the parent finishes.
- **Dynamic fibers & background tasks**: Spawn concurrent work with `background`
  or `Supervisor`, obtaining typed `Fiber` handles for deterministic joining or cancellation.
- **Isolated blocking offload**: Offload synchronous system calls and CPU-heavy operations
  to a dedicated `BlockingPool` with `IO.blocking(...)` or cancelable `IO.interruptible(...)`,
  preventing starvation of the work-stealing worker threads.
- **Resumable coordination**: Coordinate asynchronous fibers safely using `Deferred`,
  `Ref`, `Queue`, and `Semaphore`.
- **Deterministic virtual-time testing**: Control execution with `TestControl`—advancing
  virtual time instantly without wall-clock sleeps and systematically exploring concurrency
  interleavings.

The [structured async runtime guide](docs/content/guides/async-runtime.md) includes runnable
examples for fibers, coordination, timeouts, blocking offload, and Cats Effect
concept mapping. The multi-threaded work-stealing runtime is qualified on 64-bit Linux
and macOS arm64.

### Asynchronous racing, timeouts, and TestControl

Structured concurrency manages deadlines through `timeout_to` and `timeout_after`. In test environments,
`TestControl` provides deterministic virtual-time progression so timed programs execute instantly without
wall-clock sleeps:

```mojo
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Duration, TestControl

def success(value: Int) -> Int: return value
def failure(var errors: EffectFailure[Int]) -> Int: return -1
def canceled() -> Int: return 0

def main() raises:
    # A 60-second asynchronous sleep with a 5-second timeout fallback:
    var slow = IO[NoneType, Int].sleep(Duration.seconds(60)).map(lambda (unit: NoneType) -> Int: 42)
    var program = slow^.timeout_to(Duration.seconds(5), IO[Int, Int].pure(7))

    # TestControl advances virtual time instantly without wall-clock waiting:
    var control = TestControl(program^)
    control.tick()       # Advances to the first scheduling point (5s deadline)
    control.tick_all()   # Drains virtual-time deadlines and completes execution
    print("result:", fold_outcome(control^.results(), success, failure, canceled))  # result: 7
```

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

To work from source, clone the repository. Its `main` branch pins Mojo
1.2.0:

```sh
git clone https://github.com/Spellbound-Mojo/fp_mojo.git
cd fp_mojo
pixi install --locked
pixi run mojo run -I src docs/examples/quickstart.mojo   # prints 42
```

On 64-bit Linux or macOS arm64, run the async sequencing example:

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
a fourteen-part tutorial, runnable examples and an API reference generated from the
source. Its sources are in [`docs/content`](docs/content/index.md); to browse
them locally:

```sh
pixi install --locked -e docs
pixi run docs-serve
```

| Start with | For |
|---|---|
| [Tutorial](docs/content/tutorial/pipelines.md) | Fourteen runnable lessons covering pipelines, data types, a configuration processor, algebra, effects, error accumulation and async programs |
| [Algebra & Monads](docs/content/tutorial/algebra.md) | When to use mapping, applicative combination, monadic bind and traversal |
| [Effects & Transformers](docs/content/tutorial/effects.md) | Reader, State and Writer before combining them with monad transformers |
| [Error accumulation](docs/content/tutorial/accumulation.md) | Validating independent inputs with `par_map_n`, `ValidationFamily`, `NonEmptyList`, and `Ior` |
| [Capabilities](docs/content/tutorial/capabilities.md) | Cats MTL pattern with `Ask`, `Stateful`, and `Tell` capability dictionaries |
| [Async programs with IO](docs/content/tutorial/io.md) | Suspended side effects, resource scopes, and cooperative execution |
| [Fibers & Concurrency](docs/content/tutorial/fibers.md) | Cancelable fibers, joins, races, timeouts, and structured supervision |
| [Running & Testing](docs/content/tutorial/running.md) | Execution profiles, work-stealing pool, blocking offload, and `TestControl` virtual time |
| [Async runtime guide](docs/content/guides/async-runtime.md) | Architectural overview of typed sequencing, child lifecycles, and host integration |
| [Async API reference](docs/content/reference/effects.async_runtime.md) | Application operations and their ownership and cancellation contracts |
| [Examples](docs/content/examples/index.md) | Every example program, with its reviewed output |
| [Ownership and errors](docs/content/start/ownership.md) | How borrowing, moving and failures work across the library |
| [API reference](docs/content/reference/index.md) | Every public name, with its contract |
| [Architecture](docs/content/architecture/overview.md) | How it is built, and why |
| [Support and limitations](docs/content/guides/status.md) | What is covered today, and what is not |

## Status & Compatibility

- **Compiler & Toolchain**: FP Mojo 1.0.2 and the `main` branch target **Mojo 1.2.0**. FP Mojo 1.0.0 and 1.0.1 target Mojo 1.1.0.
- **Platform Support**:
  - **Linux x86-64 and macOS arm64**: Complete library support, including the multi-threaded work-stealing async runtime and POSIX driver.
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
