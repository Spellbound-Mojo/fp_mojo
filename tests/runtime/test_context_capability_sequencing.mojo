from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, StringMonoid
from fp.effects import Reader, State, Writer, run, run_writer
from fp.callables import MutableThunk
from std.testing import assert_equal
from test_algebra_third_party import Cell, CellFamily

@fieldwise_init
struct Counting(MutableThunk):
    var calls: Int
    comptime Out = List[Int]
    def call_mut(mut self) -> Self.Out:
        self.calls += 1
        return List[Int]([self.calls])

def main() raises:
    def branch(x: Int) -> List[Int]: return List[Int]([x+1, x+2])
    assert_equal(pipeline(List[Int]([1, 4])).flat_tap(branch).map(lambda (x: Int) -> Int: x+1).get(), List[Int]([2,2,5,5]))
    var paired = pipeline(List[Int]([1])).flat_pair_with(branch).get()
    assert_equal(paired, List[Tuple[Int,Int]]([(1,2),(1,3)]))
    def absent(x: Int) -> Optional[Int]: return Optional[Int]()
    assert_equal(Bool(pipeline(Optional(2)).flat_tap(absent).get()), False)
    def factory() -> List[Int]: return List[Int]([7, 8])
    assert_equal(pipeline(List[Int]([1,2])).before(factory).get(), List[Int]([1,1,2,2]))
    assert_equal(pipeline(List[Int]([1,2])).followed_by(factory).get(), List[Int]([7,8,7,8]))
    assert_equal(pipeline(List[Int]([1,2])).followed_by(Counting(0)).get(), List[Int]([1,2]))
    comptime R = Reader[Int]
    var calls = 0
    def reader(x: Int) {mut calls} -> R.Pure[Int]:
        calls += 1
        return R.pure(x+1)
    var pending = pipeline[R](R.pure(2)).flat_pair_with(reader).get()
    assert_equal(calls, 0)
    assert_equal(run[R](pending^, 0), (2,3))
    assert_equal(calls, 1)
    comptime S = State[Int]
    def state() -> S.Pure[Int]: return S.pure(8)
    assert_equal(run[S](pipeline[S](S.pure(2)).before(state).get(), 1), (2,1))
    comptime W = Writer[StringMonoid]
    def written() -> W.Pure[Int]: return W.pure(9)
    assert_equal(run_writer[W](pipeline[W](W.pure(2)).followed_by(written).get())[1], 9)
    def custom(x: Int) -> Cell[Int]: return Cell(x+1)
    var selected = pipeline[CellFamily](Cell(5)).flat_pair_with(custom)
    comptime assert type_of(selected).I == CellFamily
    assert_equal(selected^.get().take(), (5,6))
