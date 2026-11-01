from fp.callables import OnceUnary,call_once
from fp.effects.state import _MapFirst
from fp.effects.writer import _MapValue,_Censor
from std.testing import assert_equal

@fieldwise_init
struct ReturnView[V:Movable & Deinitable,E:Movable & Deinitable](OnceUnary):
    var value:Self.V
    var failure:Self.E
    var fail:Bool
    comptime Arg=Int
    comptime Out=Self.V
    comptime Error=Self.E
    def call_once(deinit self,var unused:Int) raises Self.Error ->Self.Out:
        if self.fail:raise self.failure^
        return self.value^

def check(owner:List[Int],other_owner:List[Int],error_owner:List[Int]) raises:
    comptime V=type_of(Span(owner))
    comptime O=type_of(Span(other_owner))
    comptime E=type_of(Span(error_owner))
    comptime F=ReturnView[V,E]
    comptime assert _MapFirst[F,O].Out==Tuple[V,O]
    comptime assert _MapValue[O,F].Out==Tuple[O,V]
    comptime assert _Censor[F,O].Out==Tuple[V,O]
    for fail in [False,True]:
        var caught=False
        var valid=False
        try:
            var first=call_once(_MapFirst[F,O](F(Span(owner),Span(error_owner),fail)),Tuple(1,Span(other_owner)))
            valid=first[0].unsafe_ptr()==Span(owner).unsafe_ptr() and first[1].unsafe_ptr()==Span(other_owner).unsafe_ptr()
        except error:
            comptime assert type_of(error)==E
            caught=error.unsafe_ptr()==Span(error_owner).unsafe_ptr()
        assert_equal(caught,fail)
        assert_equal(valid,not fail)
        caught=False
        valid=False
        try:
            var second=call_once(_MapValue[O,F](F(Span(owner),Span(error_owner),fail)),Tuple(Span(other_owner),1))
            valid=second[0].unsafe_ptr()==Span(other_owner).unsafe_ptr() and second[1].unsafe_ptr()==Span(owner).unsafe_ptr()
        except error:
            comptime assert type_of(error)==E
            caught=error.unsafe_ptr()==Span(error_owner).unsafe_ptr()
        assert_equal(caught,fail)
        assert_equal(valid,not fail)

def main() raises:check([1],[2],[3])
