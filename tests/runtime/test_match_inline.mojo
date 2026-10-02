"""`fp.match` on values that are not Nodes: Choice, Result, ControlFlow and Optional."""
import fp
from fp.adt import Data, Cases, Choice, Value
from fp.data import Ok, Err, Result, Break, Continue, ControlFlow
from std.testing import assert_equal


@fieldwise_init
struct InlineRed(Copyable):
    pass


@fieldwise_init
struct InlineGreen(Copyable):
    var shade: Int


@fieldwise_init
struct InlineNote(Movable):
    var text: String


struct InlineLight(Data):
    comptime Layer[R: Value] = Cases[InlineRed, InlineGreen, InlineNote]


comptime Light = Choice[InlineLight]


@fieldwise_init
struct InlineFailure(Movable):
    var code: Int


def describe(light: Light) -> String:
    """Constructor clauses, a guard and a catch-all; a movable-only field is borrowed."""
    return fp.match(light,
        lambda (r: InlineRed) -> String: "red",
        fp.when[lambda (g: InlineGreen) -> Bool: g.shade > 5, lambda (g: InlineGreen) -> String: "bright"],
        lambda (n: InlineNote) -> String: n.text,
        lambda (l: Light) -> String: "other")


def scaled(light: Light, factor: Int) -> Int:
    return fp.match(light,
        lambda (g: InlineGreen, k: Int) -> Int: g.shade * k,
        lambda (l: Light, k: Int) -> Int: 0,
        context=factor)


def checked(light: Light) raises InlineFailure -> Int:
    return fp.match(light, lambda (g: InlineGreen) -> Int: g.shade, refuse)


def refuse(l: Light) raises InlineFailure -> Int:
    raise InlineFailure(7)


def checked_code(light: Light) -> Int:
    """The value, or minus the failure code when a clause raised."""
    try:
        return checked(light)
    except error:
        return -error.code


def outcome(r: Result[Int, String]) -> String:
    return fp.match(r,
        fp.when[lambda (o: Ok[Int]) -> Bool: o.value < 0, lambda (o: Ok[Int]) -> String: "negative"],
        lambda (o: Ok[Int]) -> String: "ok " + String(o.value),
        lambda (e: Err[String]) -> String: "error " + e.value)


def owned_outcome(r: Result[InlineNote, Int]) -> String:
    return fp.match(r, lambda (o: Ok[InlineNote]) -> String: o.value.text, lambda (e: Err[Int]) -> String: String(e.value))


def flow(c: ControlFlow[String, Int]) -> String:
    return fp.match(c,
        lambda (b: Break[String]) -> String: "stop " + b.value,
        lambda (k: Continue[Int]) -> String: "go " + String(k.value))


def present(o: Optional[InlineNote]) -> String:
    return fp.match(o, lambda (n: InlineNote) -> String: n.text, lambda (n: NoneType) -> String: "none")


def nested(o: Optional[Optional[Int]]) -> Int:
    return fp.match(o,
        lambda (inner: Optional[Int]) -> Int: inner.value() if inner else 0,
        lambda (n: NoneType) -> Int: -1)


def both(a: Result[Int, Int], b: Optional[Int]) -> Int:
    """Two subjects of different kinds; every combination is covered.

    The tuple holds the subjects, so a Result that is not implicitly copyable is
    copied into it explicitly.
    """
    return fp.match((a.copy(), b),
        lambda (x: Ok[Int], y: Int) -> Int: x.value + y,
        lambda (x: Ok[Int], n: NoneType) -> Int: x.value,
        lambda (e: Err[Int], y: Optional[Int]) -> Int: -e.value)


def main() raises:
    assert_equal(describe(InlineRed()), "red")
    assert_equal(describe(InlineGreen(9)), "bright")
    assert_equal(describe(InlineGreen(1)), "other")
    assert_equal(describe(InlineNote("note")), "note")
    assert_equal(scaled(InlineGreen(3), 10), 30)
    assert_equal(scaled(InlineRed(), 10), 0)
    assert_equal(checked_code(InlineGreen(4)), 4)
    assert_equal(checked_code(InlineRed()), -7)

    assert_equal(outcome(Ok(3)), "ok 3")
    assert_equal(outcome(Ok(-3)), "negative")
    assert_equal(outcome(Err(String("bad"))), "error bad")
    assert_equal(owned_outcome(Ok(InlineNote("kept"))), "kept")
    assert_equal(owned_outcome(Err(5)), "5")

    assert_equal(flow(Break(String("now"))), "stop now")
    assert_equal(flow(Continue(2)), "go 2")

    assert_equal(present(InlineNote("here")), "here")
    assert_equal(present(None), "none")
    assert_equal(nested(Optional(Optional(4))), 4)
    assert_equal(nested(Optional(Optional[Int]())), 0)
    assert_equal(nested(Optional[Optional[Int]]()), -1)

    assert_equal(both(Ok(1), Optional(2)), 3)
    assert_equal(both(Ok(1), None), 1)
    assert_equal(both(Err(4), Optional(2)), -4)
