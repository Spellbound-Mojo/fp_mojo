"""Lazy filter_map infers one Optional layer and preserves explicit bindings."""
from fp.functions import partial, as_unary, flow, kleisli
from fp.iteration import iterated, filter_map, collect_list
from fp.callables import Unary
from fp.algebra import OptionalFamily
from fp.data import Result, Ok, Err
from std.iter import Iterator
from std.testing import assert_equal

def select(limit: Int, value: Int) -> Optional[Int]:
    if value > limit: return Optional(value)
    return None

@fieldwise_init
struct Select(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Optional[Int]: return select(2, value)

def increment(var value: Int) -> Int: return value + 1
def even(var value: Int) -> Optional[Int]:
    if value % 2 == 0: return Optional(value)
    return None

def nested(offset: Int, value: Int) -> Optional[Result[Int, String]]:
    if value == 0: return None
    if value == 1: return Optional(Result[Int, String](Err(String("retained"))))
    return Optional(Result[Int, String](Ok(offset + value)))

def absent(offset: Int, value: Int) -> Optional[Never]:
    _ = offset
    _ = value
    return None

def direct[U: Movable & Deinitable, C: Unary, I: Iterator](var callback: C, var source: I
) -> List[U] where I.Element == C.Arg and C.Out == Optional[U] and C.Error == Never:
    # Generic symbolic equality retains the established explicit payload form.
    return collect_list(filter_map[U](source^, callback^))

def fluent[U: Movable & Deinitable, C: Unary, I: Iterator](var callback: C, var source: I
) -> List[U] where I.Element == C.Arg and C.Out == Optional[U] and C.Error == Never:
    return iterated(source^).filter_map[U](callback^).collect_list()

def main() raises:
    assert_equal(direct[Int](Select(), range(5)), [3, 4])
    assert_equal(fluent[Int](Select(), range(5)), [3, 4])
    var project = partial(select, 2)
    assert_equal(collect_list(filter_map(range(5), project)), [3, 4])
    assert_equal(iterated(range(5)).filter_map(project).collect_list(), [3, 4])
    assert_equal(collect_list(filter_map[Int](range(5), project)), [3, 4])
    assert_equal(iterated(range(5)).filter_map[U=Int](project).collect_list(), [3, 4])
    assert_equal(collect_list(filter_map(range(5), Select())), [3, 4])
    assert_equal(iterated(range(5)).filter_map(Select()).collect_list(), [3, 4])
    assert_equal(collect_list(filter_map[Int](range(5), Select())), [3, 4])
    assert_equal(iterated(range(5)).filter_map[Int](Select()).collect_list(), [3, 4])
    assert_equal(iterated(range(5)).filter_map(project^).collect_list(), [3, 4])
    var native = as_unary(even)
    assert_equal(collect_list(filter_map(range(5), native)), [0, 2, 4])
    assert_equal(iterated(range(5)).filter_map(native).collect_list(), [0, 2, 4])
    var chain = flow(increment, even)
    assert_equal(collect_list(filter_map(range(5), chain)), [2, 4])
    assert_equal(iterated(range(5)).filter_map(chain).collect_list(), [2, 4])
    var effect = kleisli[OptionalFamily](even)
    assert_equal(collect_list(filter_map(range(5), effect)), [0, 2, 4])
    assert_equal(iterated(range(5)).filter_map(effect).collect_list(), [0, 2, 4])
    var outcomes = partial(nested, 10)
    var values = iterated(range(3)).filter_map(outcomes).collect_list()
    comptime assert type_of(values) == List[Result[Int, String]]
    assert_equal(len(values), 2)
    assert_equal(values[0].is_err(), True)
    assert_equal(values[1].is_ok(), True)
    var never = partial(absent, 0)
    var empty = iterated(range(3)).filter_map(never).collect_list()
    comptime assert type_of(empty) == List[Never]
    assert_equal(len(empty), 0)
