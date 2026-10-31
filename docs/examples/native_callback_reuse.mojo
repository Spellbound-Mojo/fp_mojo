"""Keep an owned native closure reusable as a library callable."""
from fp.functions import pipeline, as_unary, as_binary
from fp.iteration import iterated
from fp.callables import BinarySignature, BorrowSignature, BorrowMutableCallable, mut_ref, shared_ref


def add(var first: Int, var second: Int) -> Int: return first + second


@fieldwise_init
struct EveryOther(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: Int
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.calls += 1
        return self.calls % 2 == 0


@fieldwise_init
struct RunningKey(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Int
    var calls: Int
    def invoke_mut(mut self, ref value: Int) -> Int:
        self.calls += 1
        return value + self.calls


def main():
    var prefix = String("item-")
    def label(var value: Int) {var prefix^} -> String:
        return prefix + String(value)
    var formatter = as_unary(label^)
    print("first:", pipeline(Optional(2)).map(formatter).get_or(""))
    print("again:", pipeline(3).then(formatter).get())
    print("moved:", pipeline(4).then(formatter^).get())
    var combine = as_binary(add)
    print("running:", iterated(range(1, 4)).scan_left(combine, 0).collect_list())
    print("zipped:", iterated(range(2)).zip_with(range(3, 5), combine).collect_list())
    var sum_prefix = String("sum=")
    def format_sum(var first: Int, var second: Int) {var sum_prefix^} -> String:
        return sum_prefix + String(first + second)
    var format = BinarySignature[Int, Int, String].capture(format_sum^)
    print("captured binary:", format(2, 3), format(4, 5))
    var limit = 3
    def below(value: Int) {limit} -> Bool: return value < limit
    var selected = BorrowSignature[Int, Bool].capture(below)
    print("captured predicate:", iterated(range(5)).filter(selected).collect_list())
    print("reused predicate:", pipeline[List[Int]]([1, 4, 2]).filter(selected).get())
    print("stateful predicate:", iterated(range(5)).filter(EveryOther(0)).collect_list())
    print("stateful projection:", iterated(range(1, 4)).pair_with(RunningKey(0)).collect_list())
    print("family projection:", pipeline[List[Int]]([1, 2, 3]).pair_with(RunningKey(0)).get())
    var predicate = EveryOther(0)
    print("borrowed mutable predicate:", iterated(range(5)).filter(mut_ref(predicate)).to_list())
    print("retained calls:", predicate.calls)
    print("continued predicate:", iterated(range(3)).filter(mut_ref(predicate)).to_list())
    print("total calls:", predicate.calls)
    print("family mutable filter:", pipeline[List[Int]]([0, 1, 2, 3]).filter(mut_ref(predicate)).get())
    print("family mutable filter_not:", pipeline[List[Int]]([0, 1, 2, 3]).filter_not(mut_ref(predicate)).get())
    print("family retained calls:", predicate.calls)
    var observations = 0
    def observe(value: Int) {mut observations} -> Optional[NoneType]:
        observations += 1
        return Optional(NoneType())
    var observer = BorrowSignature[Int, Optional[NoneType]].capture(observe)
    var retained = iterated(range(3)).traverse_tap(shared_ref(observer))
    print("audited values:", retained.value())
    print("observations:", observations)
