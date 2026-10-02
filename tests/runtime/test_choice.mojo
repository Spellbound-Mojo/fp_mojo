"""`Choice`: a value of a non-recursive data type stored in place."""
from fp.adt import Data, Cases, Choice, Value
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct ChoiceCircle(Copyable, Equatable):
    var radius: Int


@fieldwise_init
struct ChoiceSquare(Copyable, Equatable):
    var side: Int


@fieldwise_init
struct ChoiceLabel(Movable):
    var text: String


struct ChoiceShape(Data):
    comptime Layer[R: Value] = Cases[ChoiceCircle, ChoiceSquare]


struct ChoiceTagged(Data):
    comptime Layer[R: Value] = Cases[ChoiceCircle, ChoiceLabel]


comptime Shape = Choice[ChoiceShape]
comptime Tagged = Choice[ChoiceTagged]


def area(shape: Shape) -> Int:
    if shape.isa[ChoiceCircle]():
        return 3 * shape[ChoiceCircle].radius * shape[ChoiceCircle].radius
    return shape[ChoiceSquare].side * shape[ChoiceSquare].side


def main() raises:
    var circle: Shape = ChoiceCircle(2)
    var square: Shape = ChoiceSquare(3)
    assert_true(circle.isa[ChoiceCircle]())
    assert_false(circle.isa[ChoiceSquare]())
    assert_equal(area(circle), 12)
    assert_equal(area(square), 9)
    assert_true(circle == ChoiceCircle(2))
    assert_false(circle == ChoiceCircle(3))
    assert_false(circle == ChoiceSquare(2))

    # A copy is independent of the original.
    var copied = square.copy()
    square = ChoiceCircle(1)
    assert_true(copied == ChoiceSquare(3))
    assert_true(square == ChoiceCircle(1))

    # Constructors that are only movable: the value moves, and unwrap moves it out.
    var tagged: Tagged = ChoiceLabel("label")
    assert_true(tagged.isa[ChoiceLabel]())
    assert_equal(tagged[ChoiceLabel].text, "label")
    var label = tagged^.unwrap[ChoiceLabel]()
    assert_equal(label.text, "label")

    # A list of values stored in place.
    var shapes: List[Shape] = [ChoiceCircle(1), ChoiceSquare(2), ChoiceCircle(3)]
    var total = 0
    for shape in shapes:
        total += area(shape)
    assert_equal(total, 3 + 4 + 27)
