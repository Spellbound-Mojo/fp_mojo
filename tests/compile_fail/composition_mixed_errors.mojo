# error: flow: stage 1 should take Int, return Int and raise composition_mixed_errors.E1 or nothing
# error: raises composition_mixed_errors.E2
from fp.functions import flow, as_unary


@fieldwise_init
struct E1(Movable):
    var n: Int


@fieldwise_init
struct E2(Movable):
    var n: Int


def first(var x: Int) raises E1 -> Int:
    raise E1(x)


def second(var x: Int) raises E2 -> Int:
    raise E2(x)


def main() raises E1:
    _ = flow(as_unary(first), as_unary(second))
