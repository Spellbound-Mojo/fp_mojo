"""Selected pipelines borrow reusable chains without callback annotations."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily, ListFamily
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from algebra_support.box import Box, BoxMonad
from std.testing import assert_equal, assert_true, assert_false


def accept(value: Int) -> Optional[Int]:
    if value < 0: return Optional[Int]()
    return Optional(value + 1)


def branch(value: Int) -> List[Int]: return [value, value + 10]


def check_operations() raises:
    var chain = kleisli[OptionalFamily](accept)
    var mapped = pipeline(List[Int]([1, -1, 3])).map(chain).get()
    assert_equal(mapped[0].value(), 2)
    assert_false(mapped[1])
    assert_equal(mapped[2].value(), 4)
    assert_equal(pipeline(Optional(3)).map(chain).get().value().value(), 4)
    assert_equal(pipeline(Optional(3)).flat_map(chain).get().value(), 4)
    assert_equal(pipeline(List[Int]([1, -1, 3])).filter_map(chain).get(), [2, 4])
    assert_equal(pipeline(List[Int]([1, 2])).traverse(chain).get().value(), [2, 3])
    assert_false(pipeline(List[Int]([1, -1])).traverse(chain).get())
    assert_equal(chain.call(4).value(), 5)
    var branching = kleisli[ListFamily](branch)
    assert_equal(pipeline(List[Int]([1, 2])).flat_map(branching).get(), [1, 11, 2, 12])
    assert_equal(branching.call(3), [3, 13])


def check_evaluation() raises:
    var calls = 0
    def validate(value: Int) {mut calls} -> Result[Int, List[String]]:
        calls += 1
        if value < 0: return Err(List[String]([String(value)]))
        return Ok(value + 1)
    var chain = kleisli[ResultFamily[List[String]]](validate)
    var failed = pipeline(List[Int]([1, -2, -3])).traverse(chain).get()
    assert_equal(failed._err().value, ["-2"])
    assert_equal(calls, 2)
    var accumulated = pipeline(List[Int]([1, -2, -3])).par_traverse(chain).get()
    assert_equal(accumulated._err().value, ["-2", "-3"])
    assert_equal(calls, 5)
    var success = pipeline(List[Int]([1, 2])).par_traverse(chain).get()
    assert_equal(success._ok().value, [2, 3])
    assert_equal(calls, 7)
    assert_equal(pipeline(Result[Int, List[String]](Ok(4))).flat_map(chain).get()._ok().value, 5)
    assert_true(pipeline(Result[Int, List[String]](Err(List[String](["source"])))).map(chain).get().is_err())
    assert_equal(calls, 8)
    assert_equal(chain.call(5)._ok().value, 6)


def fail(value: Int) raises Int -> Optional[Int]: raise value


def check_native_error() raises:
    var chain = kleisli[OptionalFamily](fail)
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[String]().map(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 7)
    try: _ = pipeline(List[Int]([11])).raising[String]().traverse(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 11)


def check_origins(owner: List[Int], failure_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(failure_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def keep(value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](keep)
    var kept = pipeline(List[View]([view])).filter_map(chain).get()
    assert_true(Pointer(to=kept[0][0]) == Pointer(to=owner[0]))
    var traversed = pipeline(List[View]([view])).traverse(chain).get()
    assert_true(Pointer(to=traversed.value()[0][1]) == Pointer(to=owner[1]))
    def reject(value: View) {failure} -> Result[Int, Failure]: return Err(failure)
    var checked = kleisli[ResultFamily[Failure]](reject)
    var rejected = pipeline(List[View]([view])).traverse(checked).get()
    assert_true(Pointer(to=rejected._err().value[0]) == Pointer(to=failure_owner[0]))


def start(value: Int) -> Result[Int, String]: return Ok(value + 1)
def render(value: Int) -> String: return String(value)
def boxed(value: Int) -> Box[Int]: return Box(value + 1)
def later(value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value + 1)


def check_selected_family() raises:
    var chain = kleisli[ResultFamily[String]](start).map(render)
    var gathered = pipeline(List[Int]([1, 2])).traverse(chain).get()
    comptime assert type_of(gathered) == Result[List[String], String]
    assert_equal(gathered^.raise_on_err(), ["2", "3"])
    var custom = kleisli[BoxMonad](boxed)
    assert_equal(pipeline(List[Int]([4, 5])).traverse(custom).get().unwrap(), [5, 6])
    assert_equal(custom.call(6).unwrap(), 7)
    var deferred = kleisli[Reader[Int]](later)
    var pending = pipeline(List[Int]([2, 3])).traverse(deferred).get()
    assert_equal(run[Reader[Int]](pending^, 0), [3, 4])
    assert_equal(run[Reader[Int]](deferred.call(4), 0), 5)


def main() raises:
    check_selected_family()
    check_operations()
    check_evaluation()
    check_native_error()
    check_origins(List[Int]([7, 11]), List[Int]([13, 17]))
