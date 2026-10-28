"""Named flow and compose values reuse the selected callback-view boundary."""
from fp.functions import pipeline, flow, compose
from fp.data import Result, Ok, Err, ok, err
from fp.effects import Reader, run
from std.testing import assert_equal, assert_false, assert_true


def add(value: Int) -> Int: return value + 1
def double(value: Int) -> Int: return value * 2
def zero() -> Int: return 3
def pair(left: Int, right: Int) -> Int: return left + right
def accept(value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()
def validate(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value)
def length(var value: String) -> Int: return value.byte_length()
def failure(value: Int) raises Int -> Int: raise value
def later(value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value)


def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: View) -> View: return value
    def wrap(var value: View) -> Optional[View]: return Optional(value)
    var chain = flow(keep, wrap)
    var retained = pipeline(List[View]([view])).traverse(chain).get()
    assert_true(Pointer(to=retained.value()[0][0]) == Pointer(to=owner[0]))
    def reject(var value: View) raises View -> View: raise value
    var raising = flow(keep, reject)
    var caught = False
    try: _ = pipeline(view).then(raising).get()
    except error:
        comptime assert type_of(error) == View
        assert_true(Pointer(to=error[1]) == Pointer(to=owner[1]))
        caught = True
    assert_true(caught)


def main() raises:
    origins([7, 11])
    var transform = flow(add, double)
    assert_equal(pipeline(List[Int]([1, 2])).map(transform).get(), [4, 6])
    assert_equal(pipeline(ok[Never](3)).map(transform).raise_on_err(), 8)
    assert_equal(pipeline(4).then(transform).get(), 10)
    assert_equal(ok[Never](5).map(transform).raise_on_err(), 12)
    assert_equal(pipeline(ok[Never](6)).map(transform^).raise_on_err(), 14)
    assert_equal(pipeline(7).then(flow(add, double)).get(), 16)
    var reverse = compose(double, add)
    assert_equal(pipeline(2).then(reverse).get(), 6)
    assert_equal(pipeline(3).then(reverse).get(), 8)

    var selected = flow(add, accept)
    assert_equal(pipeline(List[Int]([1, 2])).traverse(selected).get().value(), [2, 3])
    assert_false(pipeline(List[Int]([-2])).traverse(selected).get())
    assert_equal(pipeline(List[Int]([-2, 1, 3])).filter_map(selected).get(), [2, 4])
    assert_equal(pipeline(Optional(4)).flat_map(selected).get().value(), 5)
    assert_equal(pipeline(5).then(selected).map(double).get().value(), 12)

    var checked = flow(add, validate)
    var gathered = pipeline(List[Int]([1, 2])).traverse(checked).get()
    comptime assert type_of(gathered) == Result[List[Int], String]
    assert_equal(gathered^.raise_on_err(), [2, 3])
    assert_true(pipeline(List[Int]([-2])).traverse(checked).get().is_err())
    assert_equal(pipeline(3).then(checked).map(double).raise_on_err(), 8)

    var recover = flow(length, double)
    assert_equal(pipeline(err[Int](String("bad"))).value_or(recover), 6)
    assert_equal(err[Int](String("again")).recover(recover).raise_on_err(), 10)
    assert_equal(pipeline(ok[String](4)).fold_owned(double, recover), 8)

    var raising = flow(add, failure)
    var caught = False
    try: _ = pipeline(6).raising[String]().then(raising).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 7)
        caught = True
    assert_true(caught)

    var deferred = flow(add, later)
    var pending = pipeline(List[Int]([1, 2])).traverse[Reader[Int]](deferred).get()
    assert_equal(run[Reader[Int]](pending^, 0), [2, 3])
    assert_equal(run[Reader[Int]](deferred(4), 0), 5)

    # Other arities retain their existing calls without exposing unary views.
    var thunk = flow(zero, double)
    assert_equal(thunk(), 6)
    var binary = flow(pair, double)
    assert_equal(binary(2, 3), 10)
