"""Captured adapters integrate with native utilities and explicit Result values."""
from fp.iteration import map, scan_left, collect_list
from fp.data import Result, collect_results, Ok, Err
from std.iter import Iterator, iter, next, enumerate, zip
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CapturedFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def transfer_iterator[I: Iterator](var source: I) -> I:
    return source^

def exercise_results(drops: ArcPointer[Int]) raises:
    var calls = 0
    def transform(var value: Int) {mut calls, drops} -> Result[Int, CapturedFailure]:
        calls += 1
        if value == 2: return Result[Int, CapturedFailure](Err(CapturedFailure(27, drops)))
        return Result[Int, CapturedFailure](Ok(value * 10))
    var values = [1, 2, 3]
    var mapped = map(transform, iter(values^))
    var first = next(mapped)
    var first_value: Int
    try: first_value = first^.raise_on_err()
    except: raise Error("unexpected Err")
    assert_equal(first_value, 10)
    var failure = next(mapped)
    assert_equal(failure.is_err(), True)
    var last = next(mapped)
    var last_value: Int
    try: last_value = last^.raise_on_err()
    except: raise Error("unexpected Err")
    assert_equal(last_value, 30)
    assert_equal(calls, 3)
    # Explicit aggregation stops at Err; ordinary lazy mapping above continues.
    calls = 0
    var inputs = [1, 2, 3]
    var collected = collect_results(map(transform, iter(inputs^)))
    assert_equal(collected.is_err(), True)
    assert_equal(calls, 2)

def main() raises:
    var calls = 0
    def double(var value: Int) {mut calls} -> Int:
        calls += 1
        return value * 2
    var values = [1, 2, 3]
    var mapped = map(double, iter(values))
    var forwarded = transfer_iterator(mapped^)
    var indexed = enumerate(forwarded^)
    var outputs = List[Int]()
    while True:
        var value: Tuple[Int, Int]
        try: value = next(indexed)
        except: break
        outputs.append(value[0] * 100 + value[1])
    assert_equal(outputs, [2, 104, 206])
    assert_equal(values, [1, 2, 3])
    assert_equal(calls, 3)
    var steps = 0
    def append(var acc: String, var value: Int) {mut steps} -> String:
        steps += 1
        return acc + String(value)
    var scanned = scan_left(append, String("s"), iter(range(3)))
    var labels = [10, 20, 30, 40]
    var paired = zip(scanned^, iter(labels^))
    var snapshots = List[String]()
    while True:
        var value: Tuple[String, Int]
        try: value = next(paired)
        except: break
        snapshots.append(value[0] + ":" + String(value[1]))
    assert_equal(snapshots, ["s:10", "s0:20", "s01:30", "s012:40"])
    assert_equal(steps, 3)
    var error_drops = ArcPointer(0)
    exercise_results(error_drops)
    assert_equal(error_drops[], 2)
    # Returned iterators keep the supplied native callable type through a
    # factory boundary; this does not return a newly declared closure.
    var empty = collect_list(map(double, iter(range(0))))
    assert_equal(len(empty), 0)
