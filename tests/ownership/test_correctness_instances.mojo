"""Resource identities and retained snapshot copies, independent of drop order."""
from fp.functions import pipe, as_unary
from fp.iteration import scan_left, map
from fp.data import collect_results, Result, Ok, Err
from std.iter import iter
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Ledger(Movable):
    var live: List[Int]
    var drops: List[Int]
    var parents: List[Int]

struct CorrectnessInstancesResource(Copyable):
    var value: Int
    var id: Int
    var ledger: ArcPointer[Ledger]
    var snapshot: List[Int]
    def __init__(out self, value: Int, ledger: ArcPointer[Ledger]):
        self.value = value
        self.id = len(ledger[].live)
        ledger[].live.append(1)
        ledger[].drops.append(0)
        ledger[].parents.append(-1)
        self.ledger = ledger
        self.snapshot = [value]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.id = len(copy.ledger[].live)
        copy.ledger[].live.append(1)
        copy.ledger[].drops.append(0)
        copy.ledger[].parents.append(copy.id)
        self.ledger = copy.ledger
        self.snapshot = copy.snapshot.copy()
    def __deinit__(deinit self):
        debug_assert[assert_mode="safe"](self.ledger[].live[self.id] == 1, "duplicate destruction")
        self.ledger[].live[self.id] = 0
        self.ledger[].drops[self.id] += 1

def live(value: CorrectnessInstancesResource):
    debug_assert[assert_mode="safe"](value.ledger[].live[value.id] == 1, "dead callback payload")

def check(ledger: ArcPointer[Ledger]) raises:
    for i in range(len(ledger[].live)):
        assert_equal(ledger[].live[i], 0)
        assert_equal(ledger[].drops[i], 1)

def step(var acc: CorrectnessInstancesResource, var item: Int) -> CorrectnessInstancesResource:
    live(acc)
    acc.value -= item
    acc.snapshot.append(item)
    return acc^

def scan(length: Int, take: Int, ledger: ArcPointer[Ledger]) raises:
    var source = scan_left(step, CorrectnessInstancesResource(7, ledger), iter(range(length)))
    var retained = List[CorrectnessInstancesResource]()
    for _ in range(take):
        retained.append(source.__next__())
        assert_equal(ledger[].parents[len(ledger[].parents) - 1], 0)
        for j in range(len(retained)):
            live(retained[j])
            assert_equal(len(retained[j].snapshot), j + 1)
    if take:
        retained[0].snapshot.append(99)
        for j in range(1, len(retained)): assert_equal(len(retained[j].snapshot), j + 1)

def choose(var value: CorrectnessInstancesResource) -> Result[CorrectnessInstancesResource, CorrectnessInstancesResource]:
    live(value)
    if value.value == 2: return Result[CorrectnessInstancesResource, CorrectnessInstancesResource](Err(value^))
    return Result[CorrectnessInstancesResource, CorrectnessInstancesResource](Ok(value^))

def collection(length: Int, ledger: ArcPointer[Ledger]) raises:
    var values = List[CorrectnessInstancesResource]()
    for i in range(length): values.append(CorrectnessInstancesResource(i, ledger))
    var result = collect_results(map(choose, iter(values^)))
    if length > 2:
        debug_assert[assert_mode="safe"](result.is_err(), "first Err not retained")
        # Prefix and unconsumed tail have been released; only the error lives.
        for i in range(length):
            assert_equal(ledger[].live[i], Int(i == 2))
    else:
        debug_assert[assert_mode="safe"](result.is_ok(), "unexpected Err")
        for i in range(length): debug_assert[assert_mode="safe"](ledger[].live[i] == 1, "result element died")
    assert_equal(result.is_err(), length > 2) # keep the owner live through all observations

def pipeline(fail: Int, ledger: ArcPointer[Ledger]):
    def first(var value: CorrectnessInstancesResource) raises Int {fail} -> CorrectnessInstancesResource:
        live(value)
        if fail == 1: raise 1
        return value^
    def last(var value: CorrectnessInstancesResource) raises Int {fail} -> Int:
        live(value)
        if fail == 2: raise 2
        return value.value
    var a = as_unary(first)
    var b = as_unary(last)
    comptime Steps = TypeList.of[Trait=Movable & Deinitable, CorrectnessInstancesResource, Int]()
    try: _ = pipe[Steps, Int](CorrectnessInstancesResource(7, ledger), a, b)
    except error: debug_assert[assert_mode="safe"](error == fail, "wrong error identity")

def result_scope(tag: Bool, fail: Bool, ledger: ArcPointer[Ledger]) raises:
    var source = Result[CorrectnessInstancesResource, CorrectnessInstancesResource](Ok(CorrectnessInstancesResource(17, ledger))) if tag else Result[CorrectnessInstancesResource, CorrectnessInstancesResource](Err(CorrectnessInstancesResource(23, ledger)))
    var calls = ArcPointer(0)
    def borrowed(value: CorrectnessInstancesResource) raises Int {calls, fail} -> Int:
        live(value)
        calls[] += 1
        if fail: raise value.id + 100
        return value.id
    var failure = -1
    try: _ = source.fold(borrowed, borrowed)
    except error: failure = error
    assert_equal(calls[], 1)
    assert_equal(failure, 100 if fail else -1)
    assert_equal(ledger[].live[0], 1)
    assert_equal(source.is_ok(), tag)
    def owned(var value: CorrectnessInstancesResource) raises Int {calls, fail} -> Int:
        live(value)
        calls[] += 1
        if fail: raise value.id + 200
        return value.id
    failure = -1
    try: _ = source^.fold_owned(owned, owned)
    except error: failure = error
    assert_equal(calls[], 2)
    assert_equal(failure, 200 if fail else -1)
    assert_equal(ledger[].live[0], 0)

def main() raises:
    for tag in range(2):
        for fail in range(2):
            var ledger = ArcPointer(Ledger(List[Int](), List[Int](), List[Int]()))
            result_scope(Bool(tag), Bool(fail), ledger)
            check(ledger)
    for length in range(33):
        for take in range(length + 2):
            var ledger = ArcPointer(Ledger(List[Int](), List[Int](), List[Int]()))
            scan(length, take, ledger)
            assert_equal(len(ledger[].live), take + 1)
            check(ledger)
        var ledger = ArcPointer(Ledger(List[Int](), List[Int](), List[Int]()))
        collection(length, ledger)
        assert_equal(len(ledger[].live), length)
        check(ledger)
    for fail in range(3):
        var ledger = ArcPointer(Ledger(List[Int](), List[Int](), List[Int]()))
        pipeline(fail, ledger)
        assert_equal(len(ledger[].live), 1)
        check(ledger)
