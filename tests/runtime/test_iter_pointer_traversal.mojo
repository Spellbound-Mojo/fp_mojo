from fp.iteration import iterated
from fp.callables import as_unary
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from algebra_support.iterators import Counted
from std.testing import assert_equal


def reg_reg(var value: Int) -> Optional[Int]: return Optional(value + 1)
def reg_mem(var value: Int) -> Optional[String]: return Optional(String(value))
def mem_reg(var value: String) -> Optional[Int]: return Optional(value.byte_length())
def mem_mem(var value: String) -> Optional[String]: return Optional(value^)
def never(var value: Int) raises Never -> Optional[Int]: return Optional(value)

def checked(var value: Int) raises Int -> Optional[Int]:
    if value == 2: raise 7
    return Optional(value)

def checked_text(var value: String) raises Int -> Optional[String]:
    if value == "fail": raise 9
    return Optional(value^)

def validate(var value: Int) -> Result[Int, List[String]]:
    if value < 0: return Err(List[String]([String(value)]))
    return Ok(value)

def deferred(var value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value)
def alternative(var value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value + 100)


# An opaque pointer's ABI is admitted once by the existing native factory.
def forward[T: Movable & Deinitable, E: Movable & Deinitable](
    var values: List[T], function: def(var T) raises E thin -> Optional[T]
) raises E -> Optional[List[T]]:
    return iterated(values^).traverse(as_unary(function))

def forward_void[T: Movable & Deinitable, E: Movable & Deinitable](
    var values: List[T], function: def(var T) raises E thin -> Optional[T]
) raises E -> Optional[NoneType]:
    return iterated(values^).traverse_void(as_unary(function))


def pure() -> Optional[List[Int]]:
    var pointer: def(var Int) raises Never thin -> Optional[Int] = never
    return iterated(range(2)).traverse(pointer)


def main() raises:
    # All four input/result ABI combinations, collecting and discarding.
    var rr: def(var Int) thin -> Optional[Int] = reg_reg
    var rm: def(var Int) thin -> Optional[String] = reg_mem
    var mr: def(var String) thin -> Optional[Int] = mem_reg
    var mm: def(var String) thin -> Optional[String] = mem_mem
    assert_equal(iterated(range(2)).traverse(rr).value(), [1, 2])
    assert_equal(iterated(range(2)).traverse(rm).value(), ["0", "1"])
    assert_equal(iterated(List[String](["one", "four"])).traverse(mr).value(), [3, 4])
    assert_equal(iterated(List[String](["one", "two"])).traverse(mm).value(), ["one", "two"])
    assert_equal(Bool(iterated(range(2)).traverse_void(rr)), True)
    assert_equal(Bool(iterated(range(2)).traverse_void(rm)), True)
    assert_equal(Bool(iterated(List[String](["one"])).traverse_void(mr)), True)
    assert_equal(Bool(iterated(List[String](["one"])).traverse_void(mm)), True)
    assert_equal(iterated(range(2)).traverse[OptionalFamily](rr).value(), [1, 2])
    assert_equal(Bool(iterated(range(2)).traverse_void[G=OptionalFamily, X=Error](rr)), True)
    assert_equal(pure().value(), [0, 1])
    var never_pointer: def(var Int) raises Never thin -> Optional[Int] = never
    assert_equal(Bool(iterated(range(2)).traverse_void(never_pointer)), True)

    # Exact native errors stop before another source pull.
    var raising: def(var Int) raises Int thin -> Optional[Int] = checked
    for discard in [False, True]:
        var pulls = 0
        var error = 0
        try:
            if discard: _ = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse_void(raising)
            else: _ = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse(raising)
        except failure:
            comptime assert type_of(failure) == Int
            error = failure
        assert_equal(error, 7)
        assert_equal(pulls, 2)
    var typed: def(var String) raises Int thin -> Optional[String] = checked_text
    var forwarded: Optional[List[String]]
    try:
        forwarded = forward(List[String](["one"]), typed)
    except _: raise Error("unexpected native error")
    assert_equal(forwarded.value(), ["one"])
    var native_error = 0
    try: _ = forward_void(List[String](["fail"]), typed)
    except failure: native_error = failure
    assert_equal(native_error, 9)

    var validation: def(var Int) thin -> Result[Int, List[String]] = validate
    var stopped = iterated(List[Int]([-2, -3])).traverse(validation)
    assert_equal(stopped^.swap().raise_on_err(), ["-2"])
    var accumulated = iterated(List[Int]([-2, -3])).traverse[ValidationFamily[ListMonoid[String]]](validation)
    assert_equal(accumulated^.swap().raise_on_err(), ["-2", "-3"])
    var discarded = iterated(List[Int]([-2, -3])).traverse_void[ValidationFamily[ListMonoid[String]]](validation)
    assert_equal(discarded^.swap().raise_on_err(), ["-2", "-3"])

    # A deferred recipe owns a pointer copy, not a borrow of its local slot.
    var pointer: def(var Int) thin -> Reader[Int].Pure[Int] = deferred
    var pulls = 0
    var pending = iterated(Counted(Pointer(to=pulls), 0, 2)).traverse(pointer)
    var pending_void = iterated(range(2)).traverse_void(pointer)
    pointer = alternative
    assert_equal(pulls, 0)
    var env = 0
    assert_equal(run[Reader[Int]](pending^, env), [1, 2])
    assert_equal(pulls, 3)
    _ = run[Reader[Int]](pending_void^, env)
    assert_equal(run[Reader[Int]](pointer(3), env), 103)
