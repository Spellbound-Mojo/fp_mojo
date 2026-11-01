from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.callables import Thunk, MutableThunk, OnceThunk
from std.testing import assert_equal

def od_default() -> Int: return 7
def od_never() raises Never -> Int: return 8
def od_error() raises Int -> Int: raise 9
def od_unit() -> NoneType: return NoneType()

@fieldwise_init
struct ODShared(Thunk):
    comptime Out = Int
    def call(self) -> Int: return 11

@fieldwise_init
struct ODMutable(MutableThunk):
    var value: Int
    comptime Out = Int
    def call_mut(mut self) -> Int:
        self.value += 1
        return self.value

@fieldwise_init
struct ODOnce(OnceThunk):
    var value: Int
    comptime Out = Int
    def call_once(deinit self) -> Int: return self.value

def od_forward[T: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> T](
    var value: Optional[T], callback: F
) raises X -> T:
    return pipeline(value^).raising[X]().get_or_else(callback)

def od_pure() -> Int:
    return pipeline(Optional(1)).get_or_else(od_default) + pipeline(Optional[Int]()).get_or_else(od_never)

def main() raises:
    assert_equal(od_pure(), 9)
    assert_equal(pipeline(Optional[Int]()).get_or_else(ODShared()), 11)
    assert_equal(pipeline(Optional[Int]()).get_or_else(ODMutable(11)), 12)
    assert_equal(pipeline(Optional[Int]()).get_or_else(ODOnce(13)), 13)
    var pointer: def() thin -> Int = od_default
    assert_equal(pipeline(Optional[Int]()).get_or_else(pointer), 7)
    var calls = 0
    def default() {mut calls} -> Int:
        calls += 1
        return 19
    assert_equal(pipeline(Optional(2)).get_or_else(default), 2)
    assert_equal(calls, 0)
    assert_equal(pipeline(Optional[Int]()).get_or_else(default), 19)
    assert_equal(calls, 1)
    def checked() raises Int {mut calls} -> Int:
        calls += 1
        raise 23
    var retained = 0
    var error = 0
    try:
        retained = od_forward[T=Int, X=Int](Optional(3), checked)
        _ = od_forward[T=Int, X=Int](Optional[Int](), checked)
    except code: error = code
    assert_equal(retained, 3)
    assert_equal(error, 23)
    assert_equal(calls, 2)
    var native_error = 0
    try: _ = pipeline(Optional[Int]()).raising[Int]().get_or_else(od_error)
    except code: native_error = code
    assert_equal(native_error, 9)
    # The same method still selects Result's terminal semantics.
    assert_equal(pipeline(Result[Int, String](Ok(5))).get_or_else(default), 5)
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).get_or_else(default), 19)
    assert_equal(calls, 3)
    _ = pipeline(Optional[NoneType]()).get_or_else(od_unit)
    def empty() {mut calls} -> NoneType:
        calls += 1
        return NoneType()
    _ = pipeline(Optional[NoneType]()).get_or_else(empty)
    assert_equal(calls, 4)
    def nested() {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(99)
    var nested_value = pipeline(Optional[Optional[Int]](Optional[Int]())).get_or_else(nested)
    assert_equal(Bool(nested_value), False)
    assert_equal(calls, 4)
    assert_equal(pipeline(Optional[Optional[Int]]()).get_or_else(nested).value(), 99)
    assert_equal(calls, 5)
