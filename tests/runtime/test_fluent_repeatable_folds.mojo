"""Fluent terminal folds reuse the standalone repeatable receiver contract."""
from fp.callables import BinaryContract, Binary, MutableBinary, OnceBinary, RepeatableBinary, mut_ref, shared_ref
from fp.functions import pipeline
from fp.data import ControlFlow, Break, Continue
from std.testing import assert_equal

@fieldwise_init
struct Weight(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var total: Int, var value: Int) -> Int:
        self.calls += 1
        return total + value * self.calls

@fieldwise_init
struct Stop(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = ControlFlow[Int,Int]
    var calls: Int
    def call_mut(mut self, var total: Int, var value: Int) -> Self.Out:
        self.calls += 1
        if self.calls == 2: return Break(total + value)
        return Continue(total + value)

@fieldwise_init
struct Modes(Binary, MutableBinary, OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call(self, var total: Int, var value: Int) -> Int: return total + value
    def call_mut(mut self, var total: Int, var value: Int) -> Int:
        self.calls += 1
        return total + value * self.calls
    def call_once(deinit self, var total: Int, var value: Int) -> Int: return 999

@fieldwise_init
struct Failure(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Int
    var calls: Int
    def call_mut(mut self, var total: Int, var value: Int) raises Int -> Int:
        self.calls += 1
        if self.calls == 2: raise total + value
        return total + value

def numbers() -> List[Int]: return [1,2,3]

def generic[F: BinaryContract & Movable & Deinitable](var step: F, var initial: F.First, var values: List[F.Second]) raises F.Error -> F.First where F.Out == F.First and RepeatableBinary[F]:
    return pipeline(values^).fold_left(step^,initial^).get()

def main() raises:
    assert_equal(pipeline[List[Int]]([1,2,3]).fold_left(Weight(0),0).get(),14)
    var step = Weight(0)
    assert_equal(pipeline[List[Int]]([1,2,3]).fold_left(mut_ref(step),0).get(),14)
    assert_equal(step.calls,3)
    var values: List[Int] = [1,2,3]
    assert_equal(pipeline(values^).fold_left(Weight(0),0).get(),14)
    assert_equal(pipeline[List[Int]]([1,2,3]).reduce_optional(Weight(0)).get().value(),9)
    var stop = Stop(0)
    var result = pipeline[List[Int]]([1,2,3]).fold_until(mut_ref(stop),0).get()
    assert_equal(result^.unwrap[Break[Int]]().into_payload(),3)
    assert_equal(stop.calls,2)

    assert_equal(generic(Weight(0),0,numbers()),14)
    var shared = Modes(0)
    assert_equal(pipeline(numbers()).fold_left(shared_ref(shared),0).get(),6)
    assert_equal(shared.calls,0)
    assert_equal(pipeline(numbers()).fold_left(shared^,0).get(),14)
    assert_equal(pipeline(numbers()).fold_left(Modes(0),0).get(),14)
    assert_equal(pipeline(numbers()).fold_left(Modes(0),0).get(),14)
    var retained = Modes(0)
    assert_equal(pipeline(numbers()).fold_left(mut_ref(retained),0).get(),14)
    assert_equal(retained.calls,3)
    var empty = Weight(0)
    assert_equal(pipeline[List[Int]]([]).fold_left(mut_ref(empty),7).get(),7)
    assert_equal(Bool(pipeline[List[Int]]([]).reduce_optional(mut_ref(empty)).get()),False)
    assert_equal(pipeline[List[Int]]([42]).reduce_optional(mut_ref(empty)).get().value(),42)
    assert_equal(empty.calls,0)
    var empty_stop = Stop(0)
    var empty_result = pipeline[List[Int]]([]).fold_until(mut_ref(empty_stop),7).get()
    assert_equal(empty_result^.unwrap[Continue[Int]]().into_payload(),7)
    assert_equal(empty_stop.calls,0)
    var failure = Failure(0)
    var error_value = 0
    try:
        _ = pipeline(numbers()).raising[String]().fold_left(mut_ref(failure),0).get()
    except error:
        comptime assert type_of(error) == Int
        error_value = error
    assert_equal(error_value,3)
    assert_equal(failure.calls,2)
