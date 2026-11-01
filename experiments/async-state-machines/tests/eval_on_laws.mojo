"""Cats Effect's `AsyncLaws` for execution contexts, through the `EvalOn` capability.

Each law runs both sides under the free `run` and compares their outcomes, on
three targets: a two-worker work-stealing `Runtime`, a current-thread
`Runtime` and a two-thread `BlockingPool`. The programs are built through the
generic free functions with `Async[Int]`, and the identities also through
`LiftEvalOn` over `OptionalT`.

- `evalOnLocalPure`: `execution_context().eval_on(t) == pure(Some(t))`.
- `evalOnPureIdentity`: `pure(a).eval_on(t) == pure(a)`.
- `evalOnRaiseErrorIdentity`: `raise_error(e).eval_on(t) == raise_error(e)`.
- `evalOnCanceledIdentity`: `canceled.eval_on(t) == canceled`.
- `evalOnNeverIdentity`: `never.eval_on(t) == never`, observed through the
  same 20 ms timeout on both sides.
- `executionContextCommutativity`: reading the context before or after an
  effect gives the same pair, inside a region and outside one.
"""
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import Outcome, OptionalT, LiftEvalOn, eval_on, start_on, execution_context, join
from fp.effects.async_runtime import IO, Async, Fiber, Duration, BlockingPool, ExecutionContext, IORuntimeConfig, Profile, Runtime, run

comptime A = Async[Int]
comptime O = OptionalT[A]
comptime OE = LiftEvalOn[O, A]
comptime Context = Optional[ExecutionContext]


def check(condition: Bool, message: String):
    if not condition:
        abort(String("eval_on_laws: ", message))


def millis(count: Int) -> Duration:
    try:
        return Duration.milliseconds(count)
    except:
        abort("eval_on_laws: a valid duration")


def same(var left: Outcome[Int, Int], var right: Outcome[Int, Int]) -> Bool:
    """Whether two outcomes are equal: both canceled, equal values, or equal first errors."""
    if not left or not right:
        return not left and not right
    var l = left.take()
    var r = right.take()
    if l.is_ok() != r.is_ok():
        return False
    if l.is_ok():
        return l^._take_ok() == r^._take_ok()
    var lf = l^._take_err()
    var rf = r^._take_err()
    return lf.errors.first() == rf.errors.first() and lf.canceled == rf.canceled and len(lf.errors) == len(rf.errors)


struct One(OnceUnary, Defaultable):
    comptime Arg = NoneType
    comptime Out = Int

    def __init__(out self):
        pass

    def call_once(deinit self, var unit: NoneType) -> Int:
        return 1


# ===--- executionContextCommutativity ---=== #


struct WithContext(OnceUnary, Defaultable):
    """Read the context after the effect: a => execution_context.map(c => (a, c))."""
    comptime Arg = Int
    comptime Out = IO[Tuple[Int, Context], Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var value: Int) -> IO[Tuple[Int, Context], Int]:
        return execution_context[A]().map(PairWith(value))


@fieldwise_init
struct PairWith(OnceUnary):
    var value: Int
    comptime Arg = Context
    comptime Out = Tuple[Int, Context]

    def call_once(deinit self, var context: Context) -> Tuple[Int, Context]:
        return (self.value, context^)


@fieldwise_init
struct WithValue(OnceUnary):
    """Pair the effect's value with an already read context: c => fa.map(a => (a, c))."""
    var value: Int
    comptime Arg = Context
    comptime Out = IO[Tuple[Int, Context], Int]

    def call_once(deinit self, var context: Context) -> IO[Tuple[Int, Context], Int]:
        return IO[Int, Int].pure(self.value).map(ContextWith(context^))


struct ContextWith(OnceUnary):
    var context: Context
    comptime Arg = Int
    comptime Out = Tuple[Int, Context]

    def __init__(out self, var context: Context):
        self.context = context^

    def call_once(deinit self, var value: Int) -> Tuple[Int, Context]:
        return (value, self.context^)


def pair_of(var outcome: Outcome[Tuple[Int, Context], Int]) -> Tuple[Int, Context]:
    check(Bool(outcome) and outcome.value().is_ok(), "the commutativity program succeeds")
    return outcome.take()._take_ok()


def commutativity(target: Optional[ExecutionContext], name: String):
    for value in range(3):
        var first = IO[Int, Int].pure(value).flat_map(WithContext())
        var second = execution_context[A]().flat_map(WithValue(value))
        var left: Tuple[Int, Context]
        var right: Tuple[Int, Context]
        if target:
            left = pair_of(run(eval_on[A](first^, target.value())))
            right = pair_of(run(eval_on[A](second^, target.value())))
        else:
            left = pair_of(run(first^))
            right = pair_of(run(second^))
        check(left[0] == right[0] and left[0] == value, name + ": the effect's value on both sides")
        check(Bool(left[1]) == Bool(right[1]), name + ": the context is read on both sides")
        if left[1]:
            check(left[1].value() == right[1].value() and left[1].value() == target.value(), name + ": the same context on both sides")


# ===--- The identities ---=== #


def identities(target: ExecutionContext, name: String):
    # evalOnLocalPure
    var local = run(eval_on[A](execution_context[A](), target))
    check(Bool(local) and local.value().is_ok(), name + ": execution_context in a region succeeds")
    var context = local.take()._take_ok()
    check(Bool(context) and context.value() == target, name + ": evalOnLocalPure")
    # evalOnPureIdentity, evalOnRaiseErrorIdentity, evalOnCanceledIdentity
    check(same(run(eval_on[A](IO[Int, Int].pure(5), target)), run(IO[Int, Int].pure(5))), name + ": evalOnPureIdentity")
    check(same(run(eval_on[A](IO[Int, Int].raise_error(6), target)), run(IO[Int, Int].raise_error(6))), name + ": evalOnRaiseErrorIdentity")
    check(same(run(eval_on[A](IO[NoneType, Int].canceled().map(One()), target)), run(IO[NoneType, Int].canceled().map(One()))), name + ": evalOnCanceledIdentity")
    # evalOnNeverIdentity, through the same timeout.
    var never_left = run(eval_on[A](IO[Int, Int].never(), target).timeout_to(millis(20), IO[Int, Int].pure(-1)))
    var never_right = run(IO[Int, Int].never().timeout_to(millis(20), IO[Int, Int].pure(-1)))
    check(same(never_left^, never_right^), name + ": evalOnNeverIdentity")


# ===--- Through OptionalT ---=== #


struct JoinLayer(OnceUnary, Defaultable):
    comptime Arg = Optional[Fiber[Optional[Int], Int]]
    comptime Out = IO[Optional[Int], Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var fiber: Optional[Fiber[Optional[Int], Int]]) -> IO[Optional[Int], Int]:
        return fiber.take().join_with(IO[Optional[Int], Int].pure(Optional(-1)))


def layered(target: ExecutionContext, name: String):
    var present = run(eval_on[OE](IO[Optional[Int], Int].pure(Optional(8)), target))
    check(Bool(present) and present.value().is_ok(), name + ": a layer program in a region succeeds")
    check(present.take()._take_ok() == Optional(8), name + ": a layer value crosses the region")
    var absent = run(eval_on[OE](IO[Optional[Int], Int].pure(Optional[Int]()), target))
    check(Bool(absent) and absent.value().is_ok() and not absent.take()._take_ok(), name + ": the layer's absence crosses the region as a base success")
    var started = run(start_on[OE](IO[Optional[Int], Int].pure(Optional(9)), target).flat_map(JoinLayer()))
    check(Bool(started) and started.value().is_ok() and started.take()._take_ok() == Optional(9), name + ": start_on through the layer")
    var seen = run(eval_on[A](execution_context[OE](), target))
    check(Bool(seen) and seen.value().is_ok(), name + ": the layer's execution_context succeeds")
    var lifted = seen.take()._take_ok()
    check(Bool(lifted) and Bool(lifted.value()) and lifted.value().value() == target, name + ": the layer reads the region's context")


def every_law(target: ExecutionContext, name: String):
    identities(target, name)
    commutativity(Optional(target.copy()), name)
    layered(target, name)


def main():
    var pooled: Runtime
    var single: Runtime
    var blocking: BlockingPool
    try:
        var config = IORuntimeConfig()
        config.profile = Profile.work_stealing(2)
        pooled = Runtime(config)
        var current = IORuntimeConfig()
        current.profile = Profile.current_thread()
        single = Runtime(current)
    except:
        abort("eval_on_laws: the runtimes start")
    try:
        blocking = BlockingPool(max_workers=2)
    except:
        abort("eval_on_laws: the blocking pool's configuration")
    every_law(pooled, "work-stealing runtime")
    every_law(single, "current-thread runtime")
    every_law(blocking, "blocking pool")
    commutativity(None, "outside a region")
    print("eval_on laws: local pure, pure, raise_error, canceled and never identities, and context commutativity on every target")
