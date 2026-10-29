"""Direct and generic pairing infer types and preserve errors and continuation."""
from fp.data import Result, Ok, Err
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.functions import pipeline, pipeline_values
from fp.effects import Reader, run
from algebra_support.tuple_contracts import attached_left, attached_right, continued, reattached
from algebra_support.fill_contracts import Failing
from std.testing import assert_equal


@fieldwise_init
struct Box(Movable):
    var value: Int


def direct[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable](
    var source: Result[T, E], var value: U
) -> Result[Tuple[T, U], E]:
    return source^.tuple_right(value^)


def sum_pair(var pair: Tuple[Int, Int]) -> Int:
    return pair[0] + pair[1]


def fail(var value: Int) raises Int -> Int:
    raise value


def main() raises:
    var left = Result[Int, String](Ok(1)).tuple_left(Box(7)).to_optional()
    var pair = left.take()
    assert_equal(pair[0].value, 7)
    assert_equal(pair[1], 1)
    var right = direct(Result[Int, Never](Ok(2)), Box(8))
    comptime assert type_of(right) == Result[Tuple[Int, Box], Never]
    var present = right^.to_optional()
    var paired = present.take()
    assert_equal(paired[0], 2)
    assert_equal(paired[1].value, 8)
    var evaluations = 0
    def attachment() {mut evaluations} -> Box:
        evaluations += 1
        return Box(9)
    for ok in [False, True]:
        var source = Result[Int, String](Ok(3)) if ok else Result[Int, String](Err(String("kept")))
        var output = source.copy().tuple_right(attachment())
        assert_equal(output.is_ok(), ok)
        if not ok:
            assert_equal(output^.swap().get_or(String()), "kept")
        assert_equal(source.copy().tuple_left(4).is_ok(), pipeline(source^).tuple_left(4).get().is_ok())
    assert_equal(evaluations, 2)

    var optional = attached_left[OptionalFamily](Optional(1), Box(7))
    var generic_pair = optional.take()
    assert_equal(generic_pair[0].value, 7)
    assert_equal(generic_pair[1], 1)
    var repeated = attached_right[ListFamily](List[Int]([1, 2]), 3)
    assert_equal(repeated[0], (1, 3))
    assert_equal(repeated[1], (2, 3))
    assert_equal(len(attached_left[ListFamily](List[Int](), 3)), 0)
    assert_equal(continued[OptionalFamily](Optional(1), 9).map(sum_pair).get().value(), 10)
    var dictionary = Dict[String, Int]()
    dictionary["key"] = 1
    var selected = reattached(pipeline_values(dictionary^).raising[Int](), 7)
    comptime assert type_of(selected).E == Int
    assert_equal(selected^.map(sum_pair).get()["key"], 8)
    var stored = attached_right[ResultFamily[String]](Result[Int, String](Err(String("kept"))), Box(1))
    assert_equal(stored^.swap().get_or(String()), "kept")

    var code = 0
    try:
        _ = attached_left[Failing](17, Box(1))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 17)
    comptime R = Reader[Int]
    var pending = attached_right[R](R.pure(1), Box(10))
    var delayed_pair = run[R](pending^, 0)
    assert_equal(delayed_pair[0], 1)
    assert_equal(delayed_pair[1].value, 10)
    var failing = pipeline[R](R.pure(19)).raising[Int]().map(fail).get()
    var delayed = attached_left[R](failing^, Box(1))
    try:
        _ = run[R](delayed^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 19)
