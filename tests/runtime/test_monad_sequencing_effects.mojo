"""Sequencing retains deferred timing, state threading and transformer effects."""
from fp.algebra import ResultFamily, ListFamily, StringMonoid
from fp.effects import Reader, State, Writer, OptionalT, ResultT, action, run, writer, run_writer
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false, assert_true
from algebra_support.arrows import ReadStep, StateStep
from test_algebra_third_party import Cell, CellFamily


def mse_deferred() raises:
    var calls = ArcPointer(0)
    comptime R = Reader[Int]
    comptime RA = type_of(action[R,Int](ReadStep(0)))
    def inspect(value: Int) {calls} -> RA:
        calls[] += 1
        return action[R,Int](ReadStep(value))
    def make_reader() {calls} -> RA:
        calls[] += 1
        return action[R,Int](ReadStep(7))
    var reader = piped(action[R,Int](ReadStep(2))).flat_tap[R](inspect).before[R](make_reader).get()
    assert_equal(calls[],0)
    var environment = 10
    assert_equal(run[R](reader^,environment),12)
    assert_equal(calls[],2)
    var next_reader = piped(action[R,Int](ReadStep(2))).followed_by[R](make_reader).get()
    assert_equal(calls[],2)
    assert_equal(run[R](next_reader^,environment),17)
    calls[] = 0
    var reader_pair = piped(action[R,Int](ReadStep(2))).flat_pair_with[R](inspect).get()
    assert_equal(calls[],0)
    assert_equal(run[R](reader_pair^,environment),(12,22))
    assert_equal(calls[],1)
    calls[] = 0
    comptime S = State[Int]
    comptime SA = type_of(action[S,Int](StateStep(0)))
    def update(value: Int) {calls} -> SA:
        calls[] += 1
        return action[S,Int](StateStep(value))
    def make_state() {calls} -> SA:
        calls[] += 1
        return action[S,Int](StateStep(3))
    var state = piped(action[S,Int](StateStep(0))).flat_tap[S](update).before[S](make_state).get()
    assert_equal(calls[],0)
    var observed = run[S](state^,10)
    assert_equal(observed[0],10)
    assert_equal(observed[1],23)
    assert_equal(calls[],2)
    var next_state = piped(action[S,Int](StateStep(0))).followed_by[S](make_state).get()
    var next = run[S](next_state^,10)
    assert_equal(next[0],13)
    assert_equal(next[1],13)
    calls[] = 0
    var state_pair = piped(action[S,Int](StateStep(0))).flat_pair_with[S](update).get()
    assert_equal(calls[],0)
    assert_equal(run[S](state_pair^,10),((10,20),20))
    assert_equal(calls[],1)
    # Native exceptions are deferred with Reader, never stored in its payload.
    def fail() raises String {calls} -> RA:
        calls[] += 1
        raise String('deferred factory')
    calls[] = 0
    var failing = piped(action[R,Int](ReadStep(0))).before[R](fail).get()
    assert_equal(calls[],0)
    var failed = False
    try:
        _ = run[R](failing^,environment)
    except error:
        failed = True
        comptime assert type_of(error) == String
        assert_equal(error,'deferred factory')
    assert_true(failed)
    assert_equal(calls[],1)


def mse_layers() raises:
    comptime W = Writer[StringMonoid]
    comptime WA = type_of(writer[W,Int]((String(),0)))
    def inspect(value: Int) -> WA: return writer[W,Int]((String('b'),value+10))
    def make() -> WA: return writer[W,Int]((String('c'),3))
    var result = piped(writer[W,Int]((String('a'),2))).flat_tap[W](inspect).before[W](make).get()
    var written = run_writer[W](result^)
    assert_equal(written[0],'abc')
    assert_equal(written[1],2)
    var next = piped(writer[W,Int]((String('a'),2))).followed_by[W](make).get()
    var replaced = run_writer[W](next^)
    assert_equal(replaced[0],'ac')
    assert_equal(replaced[1],3)
    var paired = piped(writer[W,Int]((String('a'),2))).flat_pair_with[W](inspect).get()
    assert_equal(run_writer[W](paired^),(String('ab'),(2,12)))
    comptime O = OptionalT[ResultFamily[String]]
    comptime OR = Result[Optional[Int],String]
    def absent(value: Int) -> OR: return Ok(Optional[Int]())
    var empty = piped(OR(Ok(Optional(2)))).flat_tap[O](absent).get()
    assert_false(empty^.raise_on_err())
    comptime L = ResultT[ListFamily,String]
    comptime LR = Result[Int,String]
    def branch(value: Int) -> List[LR]:
        return List[LR]([LR(Ok(value+1)),LR(Err(String('branch'))),LR(Ok(value+2))])
    var expanded = piped(List[LR]([LR(Ok(4)),LR(Err(String('source')))])).flat_tap[L](branch).get()
    assert_equal(len(expanded),4)
    assert_equal(expanded[0]._ok().value,4)
    assert_equal(expanded[1]._err().value,'branch')
    assert_equal(expanded[2]._ok().value,4)
    assert_equal(expanded[3]._err().value,'source')
    var pairs = piped(List[LR]([LR(Ok(4)),LR(Err(String('source')))])).flat_pair_with[L](branch).get()
    assert_equal(len(pairs),4)
    assert_equal(pairs[0]._ok().value,(4,5))
    assert_equal(pairs[1]._err().value,'branch')
    assert_equal(pairs[2]._ok().value,(4,6))
    assert_equal(pairs[3]._err().value,'source')
    def cell(value: Int) -> Cell[Int]: return Cell(value+1)
    assert_equal(piped(Cell(5)).flat_tap[CellFamily](cell).get().take(),5)
    assert_equal(piped(Cell(5)).flat_pair_with[CellFamily](cell).get().take(),(5,6))


def main() raises:
    mse_deferred()
    mse_layers()
    print('monad sequencing effects: ok')
