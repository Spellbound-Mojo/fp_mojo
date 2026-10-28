"""Functional loops over native Mojo values and sequences."""
from fp.control import while_loop, while_loop_mut, fori_loop, fori_loop_mut, scan
from fp.callables import MutableBinary, MutableUnary, BorrowSignature, BorrowMutableCallable, mut_ref


def below_ten(value: Int) -> Bool:
    return value < 10


def double(var value: Int) -> Int:
    return 2 * value


def add_index(var index: Int, var carry: Int) -> Int:
    return carry + index


def running_total(var carry: Int, var value: Int) -> Tuple[Int, Int]:
    var total = carry + value
    return (total, total)


@fieldwise_init
struct Weighted(MutableBinary):
    var calls: Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_mut(mut self, var index: Int, var carry: Int) -> Int:
        self.calls += 1
        return carry + index * self.calls


@fieldwise_init
struct Advance(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var carry: Int) -> Int:
        self.calls += 1
        return carry + self.calls


@fieldwise_init
struct StopAfter(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    var checks: Int
    var steps: Int
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.checks += 1
        return self.checks <= self.steps


@fieldwise_init
struct WeightedScan(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int, Int]
    var calls: Int
    def call_mut(mut self, var carry: Int, var value: Int) -> Self.Out:
        self.calls += 1
        carry += self.calls * value
        return (carry, carry)


def main() raises:
    print("while:", while_loop(below_ten, double, 1))
    print("fori:", fori_loop(0, 5, add_index, 0))
    var xs: List[Int] = [1, 2, 3]
    var result = scan(running_total, 0, xs^, reverse=True)
    print("scan:", result[0], result[1])
    var body = Weighted(0)
    var weighted = fori_loop_mut[unroll=2](0, 4, body, 0)
    print("mutable fori:", weighted, "calls:", body.calls)
    var limit = 10
    def before_limit(value: Int) {limit} -> Bool: return value < limit
    var predicate = BorrowSignature[Int, Bool].capture(before_limit)
    var advance = Advance(0)
    var final = while_loop_mut(predicate, advance, 0)
    print("mutable while:", final, "calls:", advance.calls)
    var stop = StopAfter(0,3)
    var measured = Advance(0)
    var limited = while_loop_mut(mut_ref(stop),measured,0)
    print("stateful predicate:", limited, "checks:", stop.checks, "steps:", measured.calls)
    print("owned fori:", fori_loop[0,4,unroll=0](Weighted(0),0))
    var weighted_scan = scan(WeightedScan(0), 0, iter(range(1, 4)))
    print("owned scan:", weighted_scan[0], weighted_scan[1])
    print("owned while:", while_loop(StopAfter(0, 3), Advance(0), 0))
