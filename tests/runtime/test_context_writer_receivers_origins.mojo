from fp.callables import MutableUnary, MutableBinary, call_repeated
from fp.algebra import IdentityFamily, StringMonoid
from fp.effects.writer import WriterT, _WriterStep, _WriterCombine
from std.testing import assert_equal

@fieldwise_init
struct Combine[V: Copyable & Deinitable, E: Copyable & Deinitable](MutableBinary):
    var value: Self.V
    var failure: Self.E
    var fail: Bool
    var calls: Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.V
    comptime Error = Self.E
    def call_mut(mut self, var left: Int, var right: Int) raises Self.Error -> Self.Out:
        self.calls += 1
        if self.fail:
            raise self.failure.copy()
        return self.value.copy()

@fieldwise_init
struct Step[V: Copyable & Deinitable, E: Copyable & Deinitable](MutableUnary):
    var value: Self.V
    var failure: Self.E
    var fail: Bool
    var calls: Int
    comptime I = WriterT[IdentityFamily, StringMonoid]
    comptime Arg = Int
    comptime Out = Self.I.Pure[Self.V]
    comptime Error = Self.E
    def call_mut(mut self, var value: Int) raises Self.Error -> Self.Out:
        self.calls += 1
        if self.fail:
            raise self.failure.copy()
        return Self.Out(Tuple(String("b"), self.value.copy()))

def check(owner: List[Int], error_owner: List[Int]) raises:
    comptime V = type_of(Span(owner))
    comptime E = type_of(Span(error_owner))
    comptime I = WriterT[IdentityFamily, StringMonoid]
    comptime C = _WriterCombine[StringMonoid, Combine[V, E]]
    comptime S = _WriterStep[I, Step[V, E]]
    comptime assert C.Out == Tuple[String, V] and C.Error == E
    comptime assert S.Out == Tuple[String, V] and S.Error == E
    for fail in [False, True]:
        var combine = C(Combine[V, E](Span(owner), Span(error_owner), fail, 0))
        var step = S(Step[V, E](Span(owner), Span(error_owner), fail, 0))
        for _ in range(2):
            var caught = False
            var valid = False
            try:
                var result = call_repeated(combine, Tuple(String("a"), 1), Tuple(String("b"), 2))
                valid = result[0] == "ab" and result[1].unsafe_ptr() == Span(owner).unsafe_ptr()
            except error:
                comptime assert type_of(error) == E
                caught = error.unsafe_ptr() == Span(error_owner).unsafe_ptr()
            assert_equal(caught, fail)
            assert_equal(valid, not fail)
            caught = False
            valid = False
            try:
                var result = call_repeated(step, Tuple(String("a"), 1))
                valid = result[0] == "ab" and result[1].unsafe_ptr() == Span(owner).unsafe_ptr()
            except error:
                comptime assert type_of(error) == E
                caught = error.unsafe_ptr() == Span(error_owner).unsafe_ptr()
            assert_equal(caught, fail)
            assert_equal(valid, not fail)
        assert_equal(combine.function.calls, 2)
        assert_equal(step.function.calls, 2)

def main() raises:
    check([1], [2])
