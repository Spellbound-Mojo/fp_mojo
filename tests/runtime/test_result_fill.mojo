"""Direct replacement and discarding preserve outcomes and infer generic types."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal


@fieldwise_init
struct Box(Movable):
    var value: Int


def filled[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable](
    var source: Result[T, E], var value: U
) -> Result[U, E]:
    return source^.fill(value^)


def discarded[T: Movable & Deinitable, E: Movable & Deinitable](
    var source: Result[T, E]
) -> Result[NoneType, E]:
    return source^.void()


def main() raises:
    var output = Result[Int, String](Ok(1)).fill(Box(7))
    assert_equal(output^.get_or(Box(0)).value, 7)
    var error = Result[Int, String](Err(String("bad"))).fill(Box(8))
    assert_equal(error^.swap().get_or(String()), "bad")
    var generic = filled(Result[Int, String](Ok(1)), Box(9))
    assert_equal(generic^.get_or(Box(0)).value, 9)
    assert_equal(discarded(Result[Int, String](Ok(1))).is_ok(), True)
    assert_equal(discarded(Result[Int, String](Err(String("kept")))).swap().get_or(String()), "kept")

    var values: List[Int] = [7, 11]
    var collection = Result[Int, String](Ok(1)).fill(values^)
    assert_equal(collection^.get_or(List[Int]()), [7, 11])
    var pure = Result[Int, Never](Ok(1)).fill(3).void()
    comptime assert type_of(pure) == Result[NoneType, Never]
    assert_equal(pure.is_ok(), True)

    var evaluations = 0
    def replacement() {mut evaluations} -> Int:
        evaluations += 1
        return 7
    assert_equal(Result[Int, Int](Ok(1)).fill(replacement()).get_or(0), 7)
    assert_equal(Result[Int, Int](Err(2)).fill(replacement()).swap().get_or(0), 2)
    assert_equal(evaluations, 2)

    for ok in [False, True]:
        var source = Result[Int, String](Ok(1)) if ok else Result[Int, String](Err(String("kept")))
        var direct = source.copy().fill(7)
        var selected = pipeline(source.copy()).fill(7).get()
        assert_equal(direct.is_ok(), selected.is_ok())
        if ok:
            assert_equal(direct^.get_or(0), selected^.get_or(0))
        else:
            assert_equal(direct^.swap().get_or(String()), selected^.swap().get_or(String()))
        var empty = source.copy().void()
        assert_equal(empty.is_ok(), source.is_ok())
        assert_equal(empty.is_ok(), pipeline(source.copy()).void().get().is_ok())
        assert_equal(empty.is_ok(), source^.fill(None).is_ok())
