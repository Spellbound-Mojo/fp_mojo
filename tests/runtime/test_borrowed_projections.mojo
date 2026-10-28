"""Read small projections from move-only environments and state."""
from fp.effects import Reader, State, ReaderT, LiftProject, OptionalT, asks, inspect, run
from fp.algebra import OptionalFamily
from fp.callables import BorrowCallable
from std.testing import assert_equal

@fieldwise_init
struct ProjectionSettings(Movable):
    var port: Int
    var data: List[Int]

def projection_port(settings: ProjectionSettings) -> Int:
    return settings.port

def main() raises:
    var settings = ProjectionSettings(8080, [1, 2, 3])
    var read_port = asks[Reader[ProjectionSettings]](projection_port)
    assert_equal(run[Reader[ProjectionSettings]](read_port^, settings), 8080)
    var state_port = inspect[State[ProjectionSettings]](projection_port)
    var result = run[State[ProjectionSettings]](state_port^, settings^)
    assert_equal(result[0], 8080)
    assert_equal(result[1].data, [1, 2, 3])
    comptime Base = Reader[ProjectionSettings]
    comptime Layer = OptionalT[Base]
    var lifted = asks[LiftProject[Layer, Base]](projection_port)
    var other = ProjectionSettings(9000, [])
    assert_equal(run[Base](lifted^, other).value(), 9000)
    comptime R = ReaderT[OptionalFamily, ProjectionSettings]
    var optional_port = asks[R](projection_port)
    assert_equal(run[R](optional_port^, other).value(), 9000)
    var backing: List[Int] = [7, 8]
    var captured = IndependentProjection(Pointer(to=backing).as_imm())
    var projected = asks[Reader[Int]](captured^)
    var ignored = 1
    var view = run[Reader[Int]](projected^, ignored)
    assert_equal(view[1], 8)

@fieldwise_init
struct IndependentProjection[o: ImmOrigin](BorrowCallable):
    var values: Pointer[List[Int], Self.o]
    comptime Payload = Int
    comptime Result = Span[Int, Self.o]
    def invoke(self, ref ignored: Int) -> Self.Result:
        return Span(self.values[])
