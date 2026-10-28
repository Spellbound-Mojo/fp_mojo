"""Reuse ordinary function chains across selected pipeline operations."""
from fp.functions import pipeline, flow, compose, partial, tupled, first, second, split, merge
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from std.testing import assert_equal


def add_one(value: Int) -> Int: return value + 1
def double(value: Int) -> Int: return value * 2
def add(left: Int, right: Int) -> Int: return left + right
def with_fee(subtotal: Int) -> Tuple[Int, Int]: return (subtotal, 2)
def scale(factor: Int, value: Int) -> Int: return factor * value
def display(value: Int) -> String: return "price=" + String(value)
def excited(var value: String) -> String: return value + "!"
def checked(value: Int) -> Result[String, String]:
    if value < 0: return Err(String("negative"))
    return Ok(String(value))


def main() raises:
    var transform = flow(add_one, double)
    var values: List[Int] = [1, 2]
    var mapped = pipeline(values^).map(transform).get()
    assert_equal(mapped, [4, 6])
    print("mapped:", mapped)
    print("reused:", pipeline(Optional(3)).map(transform).get_or(0))

    # compose runs right to left; this chain has the same meaning.
    var reversed = compose(double, add_one)
    assert_equal(pipeline(4).then(reversed).get(), 10)

    var validate = flow(add_one, checked)
    var inputs: List[Int] = [1, 2]
    var gathered = pipeline(inputs^).traverse(validate).raise_on_err()
    print("validated:", gathered[0], gathered[1])
    print("fallback:", pipeline(-2).then(validate).get_or(String("unavailable")))

    var price = flow(add_one, partial(scale, 3))
    print("mixed:", pipeline[Int]([1, 2]).map(price).get())
    var mirrored = compose(partial(scale, 3), add_one)
    print("mirrored:", mirrored(2))
    var combine = flow(add, partial(scale, 2))
    print("running:", iterated(range(1, 4)).scan_left(combine, 0).collect_list())
    var rendered = price^.then(display).then(excited)
    print("extended:", rendered(1), rendered(2))
    print("extended reverse:", mirrored^.then(display)(2))
    var combined = rendered^.compose(add)
    print("combined:", combined(2, 3))
    var charged = flow(with_fee, tupled(add))
    print("pair stage:", charged(6))
    var tagged = first[String](partial(scale, 3))((2, String("order-7")))
    print("tagged:", tagged[0], tagged[1])
    var retitled = second[Int](excited)((6, String("ready")))
    print("second:", retitled[0], retitled[1])
    var formatted = split(display, excited)((6, String("ready")))
    print("split:", formatted[0], formatted[1])
    var summary = merge(display, double)(6)
    print("merge:", summary[0], summary[1])
