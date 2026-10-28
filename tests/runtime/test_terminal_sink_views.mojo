"""Named partials, native adapters and compositions retain terminal contracts."""
from fp.functions import partial, as_unary, flow
from fp.iteration import iterated, count_where, for_each, collect_fold
from fp.algebra import StringMonoid, Monoid
from std.memory import ArcPointer
from std.testing import assert_equal

def below(limit: Int, value: Int) -> Bool: return value < limit
def record(count: ArcPointer[Int], value: Int) -> NoneType:
    count[] += value
    return None
def show(prefix: String, value: Int) -> Optional[String]:
    if value % 2 == 0: return Optional(prefix + String(value))
    return None

def increment(var value: Int) -> Int: return value + 1
def even_text(var value: Int) -> Optional[String]:
    if value % 2 == 0: return Optional(String(value))
    return None

def stop_count(limit: Int, value: Int) raises StopIteration -> Bool:
    if value == limit: raise StopIteration()
    return True
def stop_sink(limit: Int, value: Int) raises StopIteration -> NoneType:
    if value == limit: raise StopIteration()
    return None
def stop_fold(limit: Int, value: Int) raises StopIteration -> Optional[String]:
    if value == limit: raise StopIteration()
    return Optional(String(value))

struct FailingCombine(Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String: return String()
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String:
        if right == "2": raise 2
        return left + right

def errors() raises:
    var predicate = partial(stop_count, 1)
    var sink = partial(stop_sink, 1)
    var project = partial(stop_fold, 1)
    for mode in range(6):
        var caught = False
        try:
            if mode == 0: _ = count_where(predicate, range(4))
            elif mode == 1: _ = iterated(range(4)).count_where(predicate)
            elif mode == 2: for_each(sink, range(4))
            elif mode == 3: iterated(range(4)).for_each(sink)
            elif mode == 4: _ = collect_fold[StringMonoid](project, range(4))
            else: _ = iterated(range(4)).collect_fold[StringMonoid](project)
        except error:
            comptime assert type_of(error) == StopIteration
            caught = True
        assert_equal(caught, True)
    var selected = partial(show, String())
    var code = 0
    try: _ = collect_fold[FailingCombine](selected, range(5))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 2)

def main() raises:
    errors()
    var predicate = partial(below, 3)
    assert_equal(count_where(predicate, range(5)), 3)
    assert_equal(iterated(range(5)).count_where(predicate), 3)
    var count = ArcPointer(0)
    var sink = partial(record, count)
    for_each(sink, range(4))
    iterated(range(4)).for_each(sink)
    assert_equal(count[], 12)
    var project = partial(show, String("#"))
    assert_equal(collect_fold[StringMonoid](project, range(5)), "#0#2#4")
    assert_equal(iterated(range(5)).collect_fold[StringMonoid](project), "#0#2#4")
    assert_equal(count_where(predicate, range(0)), 0)
    assert_equal(collect_fold[StringMonoid](project, range(0)), "")
    for_each(sink, range(0))
    assert_equal(count[], 12)
    # Existing read-only search overloads already borrow the same predicate.
    assert_equal(iterated(range(5)).find(predicate).value(), 0)
    assert_equal(iterated(range(5)).any(predicate), True)
    assert_equal(iterated(range(5)).all(predicate), False)
    var chain = flow(increment, even_text)
    assert_equal(collect_fold[StringMonoid](chain, range(5)), "24")
    assert_equal(iterated(range(5)).collect_fold[StringMonoid](chain), "24")
    var native = as_unary(even_text)
    assert_equal(collect_fold[StringMonoid](native, range(5)), "024")
    assert_equal(iterated(range(5)).collect_fold[StringMonoid](native), "024")
    for_each(sink^, range(4))
    assert_equal(count[], 18)
    assert_equal(iterated(range(5)).count_where(predicate^), 3)
    assert_equal(iterated(range(5)).collect_fold[StringMonoid](project^), "#0#2#4")
