"""Functional loops: sequencing, carry/output separation, errors and unrolling."""
from fp.control import while_loop, fori_loop, scan, ScanLengthError, ScanStepError
from fp.callables import BorrowCallable, Unary, Binary
from std.builtin.rebind import rebind_var
from std.testing import assert_equal, assert_true


def below(value: Int) -> Bool:
    return value < 4


def advance(var value: Int) -> Int:
    return value + 1


def checked_below(value: Int) raises Int -> Bool:
    if value < 0:
        raise 71
    return value < 4


def checked_advance(var value: Int) raises Int -> Int:
    if value == 2:
        raise 72
    return value + 1


def add_index(var index: Int, var value: Int) -> Int:
    return value + index


def checked_index(var index: Int, var value: Int) raises Int -> Int:
    if index == 3:
        raise 73
    return value + index


def emit(var carry: Int, var value: Int) -> Tuple[Int, Int]:
    return (carry + value, carry + value)


def checked_emit(var carry: Int, var value: Int) raises Int -> Tuple[Int, Int]:
    if value == 3:
        raise 74
    return (carry + value, carry + value)


def no_input(var carry: Int, var value: Tuple[]) -> Tuple[Int, Int]:
    return (carry + 1, carry)


def checked_no_input(var carry: Int, var value: Tuple[]) raises Int -> Tuple[Int, Int]:
    if carry == 3:
        raise 75
    return (carry + 1, carry)


@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) capturing -> Bool:
        return below(value)


@fieldwise_init
struct Advance(Unary):
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int:
        return value + 1


@fieldwise_init
struct Indexed(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var index: Int, var value: Int) -> Int:
        return index + value


@fieldwise_init
struct Emit(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int, Int]
    def call(self, var carry: Int, var value: Int) -> Tuple[Int, Int]:
        return emit(carry, value)


@fieldwise_init
struct EmitEmpty(Binary):
    comptime First = Int
    comptime Second = Tuple[]
    comptime Out = Tuple[Int, Int]
    def call(self, var carry: Int, var value: Tuple[]) -> Tuple[Int, Int]:
        return no_input(carry, value^)


def loops() raises:
    assert_equal(while_loop(below, advance, 0), 4)
    assert_equal(while_loop(below, advance, 8), 8)
    assert_equal(while_loop(Predicate(), Advance(), 0), 4)
    assert_equal(while_loop(checked_below, advance, 0), 4)
    var caught_1 = False
    try:
        _ = while_loop(below, checked_advance, 0)
    except error:
        caught_1 = True
        assert_equal(error, 72)
    assert_true(caught_1)
    var caught_2 = False
    try:
        _ = while_loop(checked_below, checked_advance, -1)
    except error:
        caught_2 = True
        assert_equal(error, 71)
    assert_true(caught_2)
    assert_equal(fori_loop(-2, 4, add_index, 10), 13)
    assert_equal(fori_loop(4, -2, add_index, 10), 10)
    assert_equal(fori_loop(2, 2, add_index, 10), 10)
    assert_equal(fori_loop[unroll=4](0, 7, add_index, 0), 21)
    assert_equal(fori_loop[0, 7, unroll=0](add_index, 0), 21)
    assert_equal(fori_loop[4, -2, unroll=0](add_index, 10), 10)
    assert_equal(fori_loop(0, 7, Indexed(), 0), 21)
    assert_equal(fori_loop[0, 7, unroll=0](Indexed(), 0), 21)
    var caught_3 = False
    try:
        _ = fori_loop(0, 6, checked_index, 0)
    except error:
        caught_3 = True
        assert_equal(error, 73)
    assert_true(caught_3)
    var caught_4 = False
    try:
        _ = fori_loop[0, 6, unroll=0](checked_index, 0)
    except error:
        caught_4 = True
        assert_equal(error, 73)
    assert_true(caught_4)
    # The dynamic scheduler does not subtract the two bounds.
    assert_equal(fori_loop(Int.MAX - 1, Int.MAX, add_index, 0), Int.MAX - 1)


def scans() raises:
    var xs: List[Int] = [1, 2, 3]
    var result = scan(emit, 0, xs^)
    assert_equal(result[0], 6)
    assert_equal(len(result[1]), 3)
    assert_equal(result[1][0], 1)
    assert_equal(result[1][1], 3)
    assert_equal(result[1][2], 6)
    var reversed = scan[unroll=2](emit, 0, iter(range(1, 4)), reverse=True, length=3)
    assert_equal(reversed[0], 6)
    assert_equal(reversed[1][0], 6)
    assert_equal(reversed[1][1], 5)
    assert_equal(reversed[1][2], 3)
    var empty = scan(emit, 9, List[Int]())
    assert_equal(empty[0], 9)
    assert_equal(len(empty[1]), 0)
    var full = scan[static_length=3, unroll=0](emit, 0, iter(range(1, 4)))
    assert_equal(full[1][2], 6)
    var absent = scan(no_input, 7, length=3, reverse=True)
    assert_equal(absent[0], 10)
    assert_equal(absent[1][0], 9)
    assert_equal(absent[1][2], 7)
    var constant = scan[static_length=3, unroll=0](no_input, 7)
    assert_equal(constant[0], 10)
    var values: List[Int] = [1, 2, 3]
    var structured = scan[Int](Emit(), 0, values^)
    assert_equal(structured[0], 6)
    var structured_iter = scan[Int](Emit(), 0, iter(range(1, 4)))
    assert_equal(structured_iter[0], 6)
    var structured_empty = scan[Int](EmitEmpty(), 7, length=3)
    assert_equal(structured_empty[0], 10)
    var caught_5 = False
    try:
        _ = scan(checked_emit, 0, iter(range(1, 4)))
    except error:
        caught_5 = True
        assert_true(error.isa[ScanStepError[Int]]())
        assert_equal(error[ScanStepError[Int]].error, 74)
    assert_true(caught_5)
    var caught_6 = False
    try:
        _ = scan(checked_emit, 0, List[Int](iter(range(1, 4))))
    except error:
        caught_6 = True
        assert_true(error.isa[ScanStepError[Int]]())
        assert_equal(error[ScanStepError[Int]].error, 74)
    assert_true(caught_6)
    var caught_7 = False
    try:
        _ = scan(checked_no_input, 0, length=5)
    except error:
        caught_7 = True
        assert_true(error.isa[ScanStepError[Int]]())
        assert_equal(error[ScanStepError[Int]].error, 75)
    assert_true(caught_7)
    var caught_8 = False
    try:
        _ = scan(emit, 0, iter(range(4)), length=3)
    except error:
        caught_8 = True
        assert_equal(error.expected, 3)
        assert_equal(error.actual, 4)
    assert_true(caught_8)
    var caught_9 = False
    try:
        _ = scan[static_length=3](no_input, 0, length=2)
    except error:
        caught_9 = True
        assert_equal(error.expected, 3)
        assert_equal(error.actual, 2)
    assert_true(caught_9)
    var caught_10 = False
    try:
        _ = scan(no_input, 0, length=-1)
    except error:
        caught_10 = True
        assert_equal(error.actual, -1)
    assert_true(caught_10)
    var caught_11 = False
    try:
        _ = scan(no_input, 0)
    except error:
        caught_11 = True
        assert_equal(error.actual, -1)
    assert_true(caught_11)


def main() raises:
    loops()
    scans()
