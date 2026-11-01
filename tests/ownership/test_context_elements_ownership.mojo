"""Element selection transfers storage without evaluating, copying or losing origins."""
from fp.functions import pipeline, Identity
from fp.data import NonEmptyList
from std.collections import Array, Deque
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct CEOwner(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def ceo_check(var value: CEOwner) raises CEOwner -> CEOwner:
    if value.code < 0: raise value^
    return value^


def ceo_origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var values: Array[View, 2] = [view, view]
    var selected = pipeline(values^).elements()
    var output = selected^.map(Identity[View]()).get()
    comptime assert type_of(output) == Array[View, 2]
    assert_true(Pointer(to=output[1][0]) == Pointer(to=owner[0]))


def main() raises:
    var drops = ArcPointer(0)
    var values: Array[CEOwner, 3] = [CEOwner(1, drops), CEOwner(-2, drops), CEOwner(3, drops)]
    var selected = pipeline(values^).raising[CEOwner]().elements()
    assert_equal(drops[], 0)
    var code = 0
    try: _ = selected^.map(ceo_check).get()
    except error:
        comptime assert type_of(error) == CEOwner
        code = error.code
    assert_equal(code, -2)
    assert_equal(drops[], 3)

    var queue = Deque[CEOwner]()
    queue.append(CEOwner(4, drops))
    var untouched = pipeline(queue^).get()
    assert_equal(drops[], 3)
    _ = untouched^
    assert_equal(drops[], 4)
    var nonempty = pipeline(NonEmptyList(CEOwner(5, drops))).get()
    assert_equal(drops[], 4)
    _ = nonempty^
    assert_equal(drops[], 5)
    ceo_origins(List[Int]([7, 8]))
