from fp.functions import pipeline
from fp.data import Result
from fp.callables import Thunk, MutableThunk, OnceThunk
from std.testing import assert_equal

def or_missing() -> String: return String("missing")
def or_never() raises Never -> Int: return 7
def or_native_error() raises Int -> String: raise 19
def or_double(var value: Int) -> Int: return value * 2
def or_length(var error: String) -> Int: return error.byte_length()

@fieldwise_init
struct ORShared(Thunk):
    comptime Out = Int
    def call(self) -> Int: return 11
@fieldwise_init
struct ORMutable(MutableThunk):
    var value: Int
    comptime Out = Int
    def call_mut(mut self) -> Int:
        self.value += 1
        return self.value
@fieldwise_init
struct OROnce(OnceThunk):
    var value: Int
    comptime Out = Int
    def call_once(deinit self) -> Int: return self.value

def or_forward[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable, //,
               F: def() raises X -> E](var source: Optional[T], factory: F) raises X -> Result[T,E]:
    return pipeline(source^).raising[X]().to_result(factory).get()

def or_pure() -> Int:
    return pipeline(Optional[Int]()).to_result(or_never).get()._err().value

def main() raises:
    assert_equal(or_pure(), 7)
    var present = pipeline(Optional(21)).to_result(or_missing).map(or_double).get()
    comptime assert type_of(present) == Result[Int, String]
    assert_equal(present._ok().value, 42)
    var absent = pipeline(Optional[Int]()).to_result(or_missing).map_err(or_length).get()
    comptime assert type_of(absent) == Result[Int, Int]
    assert_equal(absent._err().value, 7)
    assert_equal(pipeline(Optional[Int]()).to_result(ORShared()).get()._err().value, 11)
    assert_equal(pipeline(Optional[Int]()).to_result(ORMutable(11)).get()._err().value, 12)
    assert_equal(pipeline(Optional[Int]()).to_result(OROnce(13)).get()._err().value, 13)
    var pointer: def() thin -> String = or_missing
    assert_equal(pipeline(Optional[Int]()).to_result(pointer).swap().to_optional().value(), "missing")
    var calls = 0
    def factory() {mut calls} -> String:
        calls += 1
        return String("absent")
    assert_equal(pipeline(Optional(2)).to_result(factory).get()._ok().value, 2)
    assert_equal(calls, 0)
    assert_equal(pipeline(Optional[Int]()).to_result(factory).get()._err().value, "absent")
    assert_equal(calls, 1)
    def failed() raises Int {mut calls} -> String:
        calls += 1
        raise 23
    var retained = 0
    var caught = 0
    try:
        retained = or_forward[T=Int,E=String,X=Int](Optional(3), failed)._ok().value
        _ = or_forward[T=Int,E=String,X=Int](Optional[Int](), failed)
    except code: caught = code
    assert_equal(retained, 3)
    assert_equal(caught, 23)
    assert_equal(calls, 2)
    var native_error = 0
    try: _ = pipeline(Optional[Int]()).raising[Int]().to_result(or_native_error)
    except code: native_error = code
    assert_equal(native_error, 19)
    # A following native callback still uses the previously selected error.
    def next(var value: Int) raises Int -> Int: raise value
    var next_error = 0
    try: _ = pipeline(Optional(5)).raising[Int]().to_result(or_missing).map(next)
    except code: next_error = code
    assert_equal(next_error, 5)
    var nested = pipeline(Optional[Optional[Int]](Optional[Int]())).to_result(factory).get()
    assert_equal(nested.is_ok(), True)
    assert_equal(Bool(nested._ok().value), False)
    assert_equal(calls, 2)
    var unit = pipeline(Optional(NoneType())).to_result(factory).get()
    comptime assert type_of(unit) == Result[NoneType, String]
    assert_equal(unit.is_ok(), True)
