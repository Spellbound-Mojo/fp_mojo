"""A sum type without recursion: clauses, a guard, a context and a pair of values."""
import fp
from fp.adt import Data, Cases, Node, Value


@fieldwise_init
struct Circle(Copyable):
    var radius: Float64


@fieldwise_init
struct Rect(Copyable):
    var width: Float64
    var height: Float64


@fieldwise_init
struct Dot(Copyable):
    pass


struct Shape(Data):
    comptime Layer[R: Value] = Cases[Circle, Rect, Dot]


comptime S = Node[Shape]


def area(s: S) -> Float64:
    return fp.match(s,
        lambda (c: Circle) -> Float64: 3.0 * c.radius * c.radius,
        lambda (r: Rect) -> Float64: r.width * r.height,
        lambda (d: Dot) -> Float64: 0.0)


def describe(s: S) -> String:
    """A guarded clause applies only when its guard holds; the next clause covers the rest."""
    return fp.match(s,
        fp.when[lambda (r: Rect) -> Bool: r.width == r.height, lambda (r: Rect) -> String: "a square"],
        lambda (r: Rect) -> String: "a rectangle",
        lambda (c: Circle) -> String: "a circle",
        lambda (s: S) -> String: "something else")


def scaled_area(s: S, factor: Float64) -> Float64:
    """The context reaches every clause as its second parameter."""
    return fp.match(s,
        lambda (c: Circle, k: Float64) -> Float64: 3.0 * c.radius * c.radius * k * k,
        lambda (r: Rect, k: Float64) -> Float64: r.width * r.height * k * k,
        lambda (d: Dot, k: Float64) -> Float64: 0.0,
        context=factor)


def same_kind(a: S, b: S) -> Bool:
    """Two values matched together; the last clause takes every other combination."""
    return fp.match((a, b),
        lambda (x: Circle, y: Circle) -> Bool: True,
        lambda (x: Rect, y: Rect) -> Bool: True,
        lambda (x: Dot, y: Dot) -> Bool: True,
        lambda (x: S, y: S) -> Bool: False)


def main():
    var shapes: List[S] = [S(Circle(1.0)), S(Rect(2.0, 3.0)), S(Rect(2.0, 2.0)), S(Dot())]
    for s in shapes:
        print(describe(s), area(s), scaled_area(s, 2.0))
    print(same_kind(shapes[1], shapes[2]), same_kind(shapes[0], shapes[3]))
