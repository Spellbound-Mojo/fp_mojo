"""Checked mapping wrappers preserve target selection, ownership and origins."""
from fp.algebra import ResultFamily, MapBothContract, MapErrContract
from fp.callables import MutableUnary
from fp.data import Result
from fp.effects import Reader, ResultT, run
from std.memory import ArcPointer
from std.testing import assert_equal
from context_mapping_receiver_support import checked_both, checked_error
from context_outcome_receiver_support import MissingUnary
from context_error_mapping_support import MappingOnly, Show, Size
from test_context_error_mapping_generic import Replace
from test_context_family_outcome_ownership import OwnedValue, RaisedView
from test_context_recovery_contracts import Token, Stored


@fieldwise_init
struct Counter(MutableUnary):
    var counts: List[Int]
    comptime Arg = String
    comptime Out = Int
    def call_mut(mut self, var value: String) -> Int:
        self.counts[0] += value.byte_length()
        return self.counts[0]


def admission() raises:
    comptime I = ResultFamily[String]
    comptime V = Result[Int,String]
    comptime BadOk = MapBothContract[I,V,MissingUnary[Int,String],Size]
    comptime BadFailure = MapBothContract[I,V,Show,MissingUnary[String,Int]]
    comptime BadError = MapErrContract[I,V,MissingUnary[String,Int]]
    comptime assert BadOk.Compatible and BadFailure.Compatible and BadError.Compatible
    comptime assert not BadOk.ReceiverCompatible and not BadFailure.InvocationCompatible
    comptime assert not BadError.ReceiverCompatible and not BadError.InvocationCompatible
    var mapped = checked_both[I](I.pure(3),Show(),Size())
    comptime assert type_of(mapped).I == ResultFamily[Int]
    assert_equal(mapped^.get()._ok().value,"3")
    assert_equal(checked_error[I](I.fail[Int](String("four")),Size()).get()._err().value,4)
    assert_equal(checked_error[I](I.fail[Int](String("abc")),Counter(List[Int]([10]))).get()._err().value,13)
    var custom = checked_both[MappingOnly[String]](I.fail[Int](String("five")),Show(),Size())
    comptime assert type_of(custom).I == MappingOnly[Int]
    assert_equal(custom^.get()._err().value,4)
    assert_equal(checked_both[I,Target=ResultFamily[Int]](I.fail[Int](String("six")),Show(),Size()).get()._err().value,3)


def deferred[error_only: Bool, success: Bool, execute: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(7,drops)) if success else I.fail[Token](Token(9,drops))
    comptime if error_only:
        var pending = checked_error[I](source^,OwnedValue[10](Token(3,drops),calls)).get()
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        comptime if execute:
            var result = run[R](pending^,0)
            comptime if success: assert_equal(result._ok().value.value,7)
            else: assert_equal(result._err().value.value,9)
            _ = result^
        else: _ = pending^
    else:
        var pending = checked_both[I](source^,OwnedValue[1](Token(2,drops),calls),OwnedValue[10](Token(3,drops),calls)).get()
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        comptime if execute:
            var result = run[R](pending^,0)
            comptime if success: assert_equal(result._ok().value.value,7)
            else: assert_equal(result._err().value.value,9)
            _ = result^
        else: _ = pending^
    assert_equal(drops[],2 if error_only else 3)
    assert_equal(calls[],0 if not execute or (error_only and success) else 1 if success else 10)


def origins(left: List[Int], right: List[Int]) raises:
    comptime L = type_of(Span(left))
    comptime R = type_of(Span(right))
    comptime I = ResultFamily[L]
    var mapped = checked_error[I,Target=ResultFamily[R]](I.fail[L](Span(left)),Replace[L,R](Span(right)))
    comptime assert type_of(mapped).I == ResultFamily[R]
    assert_equal(mapped^.get()._err().value.unsafe_ptr() == Span(right).unsafe_ptr(),True)
    comptime Environment = Reader[Int]
    comptime D = ResultT[Environment,L]
    comptime assert MapBothContract[D,D.Pure[L],RaisedView[L],Stored[L]].Error == Never
    var pending = checked_both[D](D.pure(Span(left)),RaisedView[L](),Stored[L]()).get()
    var caught = False
    try: _ = run[Environment](pending^,0)
    except error:
        comptime assert type_of(error) == L
        caught = error.unsafe_ptr() == Span(left).unsafe_ptr()
    assert_equal(caught,True)


def main() raises:
    admission()
    deferred[False,True,True]()
    deferred[False,False,True]()
    deferred[False,True,False]()
    deferred[False,False,False]()
    deferred[True,True,True]()
    deferred[True,False,True]()
    deferred[True,True,False]()
    deferred[True,False,False]()
    origins(List[Int]([7]),List[Int]([8]))
