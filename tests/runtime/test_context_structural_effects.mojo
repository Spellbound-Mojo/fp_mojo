"""Structural admission delegates custom errors, accumulation and deferred timing."""
from fp.functions import pipeline
from fp.callables import Unary
from fp.algebra import Functor, ListFamily, ValidationFamily, ListMonoid
from fp.callables import UnaryContract
from fp.effects import Reader,run
from fp.data import Result,Ok,Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_traversal_generic import ContextTraversalSource,ContextTraversalCompactFailure
from test_context_structural_behavior import Plus

struct FailingMap(Functor):
    comptime Element[V:Movable & Deinitable]=ListFamily.Element[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Int
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var value:V) raises Int -> Self.Mapped[V,F]:
        raise 17

@fieldwise_init
struct FailingCall(Unary):
    var calls:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=Int
    comptime Error=Int
    def call(self,var value:Int) raises Int -> Int:
        self.calls[] += 1
        raise value

def main() raises:
    var code=0
    try: _ = pipeline[FailingMap](List[Int]([1])).fill(String("x")).get()
    except error: code=error
    assert_equal(code,17)
    try: _ = pipeline[ContextTraversalSource](List[Optional[Int]]([Optional(1)])).compact().get()
    except error:
        comptime assert type_of(error)==ContextTraversalCompactFailure
        code=error.code
    assert_equal(code,99)
    comptime Validation=ValidationFamily[ListMonoid[String]]
    var failed=pipeline[Validation](Result[Plus,List[String]](Err(List[String](["left"])))).ap(Result[Int,List[String]](Err(List[String](["right"])))).get()
    assert_equal(failed._err().value,List[String](["left","right"]))
    comptime Deferred=Reader[Int]
    var calls=ArcPointer(0)
    var pending=pipeline[Deferred](Deferred.pure(FailingCall(calls))).ap(Deferred.pure(23)).get()
    assert_equal(calls[],0)
    try: _ = run[Deferred](pending^,0)
    except error: code=error
    assert_equal(code,23); assert_equal(calls[],1)
    var paired=pipeline[Deferred](Deferred.pure(3)).tuple_right(String("value")).get()
    assert_equal(run[Deferred](paired^,0)[1],"value")

    views(List[Int]([3,4]),List[Int]([5]))

def views(owner:List[Int],other:List[Int]) raises:
    comptime View=type_of(Span(owner))
    var replaced=pipeline(List[Int]([1,2])).fill(Span(owner)).get()
    assert_equal(replaced[0].unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var paired=pipeline(List[View]([Span(owner)])).tuple_right(Span(other)).get()
    assert_equal(paired[0][0].unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    assert_equal(paired[0][1].unsafe_ptr()==Span(other).unsafe_ptr(),True)
    var flat=pipeline(Optional(Optional(Span(owner)))).flatten().get()
    assert_equal(flat.value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
