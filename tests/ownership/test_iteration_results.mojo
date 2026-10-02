"""Result aggregation: first error, no speculative pulls, and owned cleanup."""
from fp.data import Result, Ok, Err, collect_results
from std.iter import Iterator, iter
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct IterationResultsToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct IterationResultsFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = Result[IterationResultsToken, IterationResultsFailure]
    var index: Int
    var length: Int
    var fail_at: Int
    var pulls: ArcPointer[Int]
    var drops: ArcPointer[Int]
    var errors: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Self.Element:
        self.pulls[] += 1
        if self.index == self.length: raise StopIteration()
        self.index += 1
        if self.index == self.fail_at:
            return Self.Element(Err(IterationResultsFailure(500 + self.index, self.errors)))
        return Self.Element(Ok(IterationResultsToken(self.index, self.drops)))

def exercise(library: Bool, length: Int, fail_at: Int, pulls: ArcPointer[Int],
             drops: ArcPointer[Int], errors: ArcPointer[Int]) -> Int:
    var source = Source(0, length, fail_at, pulls, drops, errors)
    var values = List[IterationResultsToken]()
    if library:
        var result = collect_results(source^)
        if result.is_err():
            # The successful prefix is already destroyed at the Err boundary.
            debug_assert(drops[] == fail_at - 1, "prefix cleanup")
        try: values = result^.raise_on_err()
        except error: return -error.code
    else:
        while True:
            var item: Result[IterationResultsToken, IterationResultsFailure]
            try: item = source.__next__()
            except: break
            try: values.append(item^.raise_on_err())
            except error: return -error.code
    var sum = 0
    for i in range(len(values)): sum += values[i].value
    return sum

def owned_tail(drops: ArcPointer[Int], errors: ArcPointer[Int]) raises:
    var source: List[Result[IterationResultsToken, IterationResultsFailure]] = [
        Result[IterationResultsToken, IterationResultsFailure](Ok(IterationResultsToken(1, drops))),
        Result[IterationResultsToken, IterationResultsFailure](Err(IterationResultsFailure(42, errors))),
        Result[IterationResultsToken, IterationResultsFailure](Ok(IterationResultsToken(3, drops))),
        Result[IterationResultsToken, IterationResultsFailure](Err(IterationResultsFailure(99, errors))),
    ]
    var result = collect_results(iter(source^))
    assert_equal(drops[], 2)
    assert_equal(errors[], 1)
    var caught = False
    try: _ = result^.raise_on_err()
    except error:
        caught = True
        assert_equal(error.code, 42)
    assert_equal(caught, True)

def main() raises:
    for length in range(6):
        for fail_at in range(7):
            var outputs = List[Int]()
            for library in range(2):
                var pulls = ArcPointer(0)
                var drops = ArcPointer(0)
                var errors = ArcPointer(0)
                outputs.append(exercise(Bool(library), length, fail_at, pulls, drops, errors))
                var failed = fail_at > 0 and fail_at <= length
                assert_equal(pulls[], fail_at if failed else length + 1)
                assert_equal(drops[], fail_at - 1 if failed else length)
                assert_equal(errors[], Int(failed))
            assert_equal(outputs[0], outputs[1])
    var drops = ArcPointer(0)
    var errors = ArcPointer(0)
    owned_tail(drops, errors)
    assert_equal(drops[], 2)
    assert_equal(errors[], 2)
    var values: List[Result[Int, StopIteration]] = [Result[Int, StopIteration](Err(StopIteration()))]
    var result = collect_results(iter(values^))
    assert_equal(result.is_err(), True)
    var infallible: List[Result[Int, Never]] = [Result[Int, Never](Ok(4))]
    var collected = collect_results(iter(infallible^)).raise_on_err()
    assert_equal(collected[0], 4)
