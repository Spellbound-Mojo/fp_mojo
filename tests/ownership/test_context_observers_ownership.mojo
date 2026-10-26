"""Borrowing observers retain move-only inputs and clean up results, failures and captures."""
from fp.functions import pipeline
from fp.callables import BorrowCallable
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ContextObserversOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct ContextObserversOwnedCallback(BorrowCallable):
    var token: ContextObserversOwner
    var calls: ArcPointer[Int]
    comptime Payload = ContextObserversOwner
    comptime Result = Int
    def invoke(self, ref input: Self.Payload) capturing -> Int:
        self.calls[] += 1
        return self.token.id + input.id

def owners(drops: ArcPointer[Int]) -> List[ContextObserversOwner]:
    var output = List[ContextObserversOwner]()
    for i in range(3): output.append(ContextObserversOwner(i + 1, drops))
    return output^

def captured(drops: ArcPointer[Int]) raises:
    var token = ContextObserversOwner(0, drops)
    @always_inline
    def count(value: Int) {var token^} -> Int:
        token.id += 1
        return token.id
    var pairs = pipeline(List[Int]([7, 8, 9])).pair_with(count).get()
    assert_equal(pairs[0][1], 1)
    assert_equal(pairs[2][1], 3)
    assert_equal(count(0), 4)
    assert_equal(drops[], 0)
    _ = count^

def main() raises:
    var inputs = ArcPointer(0)
    var results = ArcPointer(0)
    var captures = ArcPointer(0)
    var calls = ArcPointer(0)
    def project(input: ContextObserversOwner) {results} -> ContextObserversOwner:
        return ContextObserversOwner(input.id + 10, results)
    var kept = pipeline(ContextObserversOwner(1, inputs)).tap(project).get()
    assert_equal(results[], 1)
    assert_equal(inputs[], 0)
    assert_equal(kept.id, 1)
    _ = kept^
    assert_equal(inputs[], 1)
    inputs[] = 0
    results[] = 0
    var xs = pipeline(owners(inputs)).tap_each(project).get()
    assert_equal(results[], 3)
    assert_equal(inputs[], 0)
    _ = xs^
    assert_equal(inputs[], 3)
    inputs[] = 0
    results[] = 0
    var pairs = pipeline(owners(inputs)).pair_with(project).get()
    assert_equal(pairs[2][0].id, 3)
    assert_equal(pairs[2][1].id, 13)
    assert_equal(inputs[], 0)
    assert_equal(results[], 0)
    _ = pairs^
    assert_equal(inputs[], 3)
    assert_equal(results[], 3)
    inputs[] = 0
    def rejected(input: ContextObserversOwner) -> Bool: return input.id != 2
    var filtered = pipeline(owners(inputs)).filter_not(rejected).get()
    assert_equal(inputs[], 2)
    assert_equal(filtered[0].id, 2)
    _ = filtered^
    assert_equal(inputs[], 3)

    inputs[] = 0
    results[] = 0
    def fail(input: ContextObserversOwner) raises Int {results} -> ContextObserversOwner:
        if input.id == 2: raise 2
        return ContextObserversOwner(input.id, results)
    var code = 0
    try: _ = pipeline(owners(inputs)).raising[Int]().pair_with(fail).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 3)
    assert_equal(results[], 1)
    inputs[] = 0
    results[] = 0
    try: _ = pipeline(owners(inputs)).raising[Int]().tap_each(fail).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 3)
    assert_equal(results[], 1)
    inputs[] = 0
    try: _ = pipeline(ContextObserversOwner(2, inputs)).raising[Int]().tap(fail).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 1)
    inputs[] = 0
    def fail_predicate(input: ContextObserversOwner) raises Int -> Bool:
        if input.id == 2: raise 2
        return False
    try: _ = pipeline(owners(inputs)).raising[Int]().filter_not(fail_predicate).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 3)

    # A consumed library observer's state is dropped even when there is no payload.
    _ = pipeline(Optional[ContextObserversOwner]()).tap_each(ContextObserversOwnedCallback(ContextObserversOwner(0, captures), calls)).get()
    assert_equal(captures[], 1)
    assert_equal(calls[], 0)
    captures[] = 0
    inputs[] = 0
    comptime Deferred = Reader[Int]
    var pending = pipeline[Deferred](Deferred.pure(ContextObserversOwner(4, inputs))).pair_with(ContextObserversOwnedCallback(ContextObserversOwner(10, captures), calls)).get()
    assert_equal(calls[], 0)
    assert_equal(captures[], 0)
    var done = run[Deferred](pending^, 0)
    assert_equal(done[0].id, 4)
    assert_equal(done[1], 14)
    assert_equal(calls[], 1)
    assert_equal(captures[], 1)
    _ = done^
    assert_equal(inputs[], 1)
    var abandoned = pipeline[Deferred](Deferred.pure(ContextObserversOwner(5, inputs))).tap_each(ContextObserversOwnedCallback(ContextObserversOwner(0, captures), calls)).get()
    _ = abandoned^
    assert_equal(calls[], 1)
    assert_equal(captures[], 2)
    assert_equal(inputs[], 2)
    var native_captures = ArcPointer(0)
    captured(native_captures)
    assert_equal(native_captures[], 1)
