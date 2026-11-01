"""Projection, fallback, reduction and looping retain linear ownership."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import BorrowOnceCallable, OnceThunk, MutableUnary, MutableBinary, Unary
from fp.effects import Reader, State, asks, inspect, run
from fp.algebra import IdentityFamily, OptionalFamily, Semigroup, tail_rec_m, or_else_absent, get_or_else_effect
from fp.iteration import reduce_non_empty, reduce_map
from fp.data import NonEmptyList, ControlFlow, Continue, Break

@fieldwise_init
struct ErgonomicCounts(Movable):
    var created: Int
    var destroyed: Int
    var calls: Int

struct ErgonomicOwner(Movable):
    var value: Int
    var counts: ArcPointer[ErgonomicCounts]
    def __init__(out self, value: Int, var counts: ArcPointer[ErgonomicCounts]):
        self.value = value
        self.counts = counts^
        self.counts[].created += 1
    def __deinit__(deinit self):
        self.counts[].destroyed += 1

@fieldwise_init
struct ProjectOwned(BorrowOnceCallable):
    var owned: ErgonomicOwner
    comptime Payload = ErgonomicOwner
    comptime Result = ErgonomicOwner
    def invoke_once(deinit self, ref payload: Self.Payload) -> Self.Result:
        self.owned.counts[].calls += 1
        self.owned.value += payload.value
        return self.owned^

@fieldwise_init
struct OwnedFallback(OnceThunk):
    var owned: ErgonomicOwner
    comptime Out = Optional[ErgonomicOwner]
    def call_once(deinit self) -> Self.Out:
        self.owned.counts[].calls += 1
        return Optional(self.owned^)

@fieldwise_init
struct OwnedLoopStep(MutableUnary):
    var counts: ArcPointer[ErgonomicCounts]
    comptime Arg = ErgonomicOwner
    comptime Out = Optional[ControlFlow[ErgonomicOwner, ErgonomicOwner]]
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.counts[].calls += 1
        if value.value == 1000:
            return Optional(ControlFlow[ErgonomicOwner, ErgonomicOwner](Break(value^)))
        value.value += 1
        return Optional(ControlFlow[ErgonomicOwner, ErgonomicOwner](Continue(value^)))

@fieldwise_init
struct ReductionFailure(Movable):
    var owner: ErgonomicOwner

@fieldwise_init
struct OwnedReduction(MutableBinary):
    var calls: Int
    comptime First = ErgonomicOwner
    comptime Second = ErgonomicOwner
    comptime Out = ErgonomicOwner
    comptime Error = ReductionFailure
    def call_mut(mut self, var left: Self.First, var right: Self.Second) raises Self.Error -> Self.Out:
        self.calls += 1
        left.counts[].calls += 1
        if right.value < 0:
            raise ReductionFailure(right^)
        left.value += right.value
        return left^

struct OwnedAdd(Semigroup):
    comptime Value = ErgonomicOwner
    comptime Error = ReductionFailure
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        var step = OwnedReduction(0)
        return step.call_mut(left^, right^)

@fieldwise_init
struct OwnedIdentity(Unary, Copyable, Defaultable):
    comptime Arg = ErgonomicOwner
    comptime Out = ErgonomicOwner
    def call(self, var value: Self.Arg) -> Self.Out: return value^


def main() raises:
    var projected = ArcPointer(ErgonomicCounts(0, 0, 0))
    var env = ErgonomicOwner(3, projected.copy())
    var program = asks[Reader[ErgonomicOwner]](ProjectOwned(ErgonomicOwner(4, projected.copy())))
    assert_equal(projected[].calls, 0)
    var output = run[Reader[ErgonomicOwner]](program^, env)
    assert_equal(output.value, 7)
    assert_equal(env.value, 3)
    _ = output^
    _ = env^
    assert_equal(projected[].destroyed, 2)
    var state_program = inspect[State[ErgonomicOwner]](ProjectOwned(ErgonomicOwner(2, projected.copy())))
    var state_output = run[State[ErgonomicOwner]](state_program^, ErgonomicOwner(5, projected.copy()))
    assert_equal(state_output[0].value, 7)
    assert_equal(state_output[1].value, 5)
    _ = state_output^
    assert_equal(projected[].destroyed, projected[].created)

    for present in [True, False]:
        var counts = ArcPointer(ErgonomicCounts(0, 0, 0))
        var source = Optional[ErgonomicOwner]()
        if present:
            source = Optional(ErgonomicOwner(1, counts.copy()))
        var selected = or_else_absent[IdentityFamily](OwnedFallback(ErgonomicOwner(9, counts.copy())), source^)
        assert_equal(selected.value().value, 1 if present else 9)
        assert_equal(counts[].calls, 0 if present else 1)
        _ = selected^
        assert_equal(counts[].created, counts[].destroyed)

    var looping = ArcPointer(ErgonomicCounts(0, 0, 0))
    var finished = tail_rec_m[OptionalFamily](ErgonomicOwner(0, looping.copy()), OwnedLoopStep(looping.copy()))
    assert_equal(finished.value().value, 1000)
    assert_equal(looping[].calls, 1001)
    _ = finished^
    assert_equal(looping[].destroyed, 1)

    for mapped in [False, True]:
        var counts = ArcPointer(ErgonomicCounts(0, 0, 0))
        var values = NonEmptyList(ErgonomicOwner(1, counts.copy()), [ErgonomicOwner(-2, counts.copy()), ErgonomicOwner(3, counts.copy())])
        var caught = False
        try:
            if mapped:
                _ = reduce_map[OwnedAdd](values^, OwnedIdentity())
            else:
                _ = reduce_non_empty(values^, OwnedReduction(0))
        except error:
            caught = error.owner.value == -2
        assert_true(caught)
        assert_equal(counts[].calls, 1)
        assert_equal(counts[].created, counts[].destroyed)
