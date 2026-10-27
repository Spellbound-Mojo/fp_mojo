from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct SwapOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var result = Result[Int, View](Err(view)).swap()
    comptime assert type_of(result) == Result[View, Int]
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var restored = pipeline(result^).swap().swap().to_optional()
    assert_equal(Pointer(to=restored.value()[1]) == Pointer(to=owner[1]), True)

def main() raises:
    var drops = ArcPointer(0)
    var failure = Result[Int, SwapOwner](Err(SwapOwner(1, drops))).swap()
    assert_equal(failure._ok().value.value, 1)
    assert_equal(drops[], 0)
    var restored = failure^.swap()
    assert_equal(restored._err().value.value, 1)
    _ = restored^
    assert_equal(drops[], 1)
    var success = Result[SwapOwner, Int](Ok(SwapOwner(2, drops))).swap()
    assert_equal(success._err().value.value, 2)
    assert_equal(drops[], 1)
    _ = success^
    assert_equal(drops[], 2)
    var error_value = pipeline(Result[Int, SwapOwner](Err(SwapOwner(3, drops)))).swap().to_optional()
    assert_equal(error_value.value().value, 3)
    assert_equal(drops[], 2)
    _ = error_value^
    assert_equal(drops[], 3)
    var discarded = pipeline(Result[SwapOwner, Int](Ok(SwapOwner(4, drops)))).swap().to_optional()
    assert_equal(Bool(discarded), False)
    assert_equal(drops[], 4)
    var same = Result[SwapOwner, SwapOwner](Err(SwapOwner(5, drops))).swap().swap()
    assert_equal(same._err().value.value, 5)
    _ = same^
    assert_equal(drops[], 5)
    var owner: List[Int] = [3, 7]
    origins(owner)
