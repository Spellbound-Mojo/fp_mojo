"""Fill moves once, copies only for repeated calls and cleans up skipped values."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline, piped
from fp.algebra import ResultFamily, OptionalFamily, Functor
from fp.callables import UnaryContract
from fp.effects import Reader, run
from fp.iteration import iterated
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal


def result_fill[route: Int](ok: Bool) raises:
    var state = trace()
    var source = Result[Token, Token](Ok(Token(1, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var output: Result[Token, Token]
    comptime if route == 0:
        output = pipeline(source^).fill(Token(3, state)).get()
    elif route == 1:
        output = piped(source^).fill(Token(3, state)).get()
    else:
        output = piped(source^).fill[ResultFamily[Token]](Token(3, state)).get()
    assert_equal(output.is_ok(), ok)
    assert_equal(state[].drops[1], Int(ok))
    assert_equal(state[].drops[2], 0)
    assert_equal(state[].drops[3], Int(not ok))
    _ = output^
    assert_equal(state[].drops[2], Int(not ok))
    assert_equal(state[].drops[3], 1)


def optional_fill[route: Int](present: Bool) raises:
    var state = trace()
    var source = Optional(Token(1, state)) if present else Optional[Token]()
    var output: Optional[Token]
    comptime if route == 0:
        output = pipeline(source^).fill(Token(3, state)).get()
    elif route == 1:
        output = piped(source^).fill(Token(3, state)).get()
    else:
        output = piped(source^).fill[OptionalFamily](Token(3, state)).get()
    assert_equal(Bool(output), present)
    assert_equal(state[].drops[1], Int(present))
    assert_equal(state[].drops[3], Int(not present))
    _ = output^
    assert_equal(state[].drops[3], 1)


@fieldwise_init
struct Counted(Copyable):
    var state: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.state = copy.state
        self.state[].factories += 1
    def __deinit__(deinit self):
        self.state[].drops[3] += 1


def copy_policy() raises:
    var state = trace()
    var single = pipeline(Optional(1)).fill(Counted(state)).get()
    assert_equal(state[].factories, 0)
    assert_equal(state[].drops[3], 0)
    _ = single^
    assert_equal(state[].drops[3], 1)
    var repeated = pipeline(List[Int]([1, 2, 3])).fill(Counted(state)).get()
    assert_equal(state[].factories, 3)
    assert_equal(state[].drops[3], 2)
    _ = repeated^
    assert_equal(state[].drops[3], 5)
    var lazy = iterated(range(2)).fill(Counted(state))
    assert_equal(state[].factories, 3)
    var collected = lazy^.to_list()
    assert_equal(state[].factories, 5)
    assert_equal(state[].drops[3], 6)
    _ = collected^
    assert_equal(state[].drops[3], 8)


def deferred[execute: Bool]() raises:
    var state = trace()
    comptime R = Reader[Int]
    var pending = pipeline[R](R.pure(Token(1, state))).fill(Token(3, state)).get()
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[3], 0)
    comptime if execute:
        var output = run[R](pending^, 0)
        assert_equal(output.id, 3)
        assert_equal(state[].drops[1], 1)
        assert_equal(state[].drops[3], 0)
        _ = output^
    else:
        _ = pending^
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def external(owner: List[Int]) -> Result[Span[Int, origin_of(owner)], Int]:
    return pipeline(Result[Int, Int](Ok(1))).fill(Span(owner)).get()


struct FailingMap(Functor):
    comptime Element[V: Movable & Deinitable] = V
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Int -> F.Out:
        raise 17


def family_failure() raises:
    var state = trace()
    var caught = 0
    try:
        _ = pipeline[FailingMap](Token(1, state)).fill(Token(3, state)).get()
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 17)
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def main() raises:
    comptime for route in range(3):
        for present in [False, True]:
            result_fill[route](present)
            optional_fill[route](present)
    copy_policy()
    family_failure()
    deferred[False]()
    deferred[True]()
    var owner: List[Int] = [7]
    var output = external(owner)
    var view = output^.get_or(Span(owner))
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
