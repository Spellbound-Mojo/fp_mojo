"""Native no-value callbacks preserve register arguments through borrowed and stored calls."""
from fp.data import Result, Capture, raise_on_err
from fp.functions import as_unary, pipe
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct RegisterVoidCapture(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct RegisterVoidFailure(Movable):
    var code: Int

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var value: A
) -> Result[R, Never]:
    return Capture.args(value^).run(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A) raises E -> R](
    function: F, var value: A
) -> Result[R, E]:
    return Capture[E].args(value^).run(function)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var value: A
) -> Result[R, Never]:
    return capture(function, value^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A) raises E -> R](
    function: F, var value: A
) -> Result[R, E]:
    return capture(function, value^)

def thin_pure(value: Int):
    _ = value

def thin_never(value: Int) raises Never:
    _ = value

def thin_raising(value: Int) raises RegisterVoidFailure:
    if value < 0: raise RegisterVoidFailure(value)

def explicit_none(value: Int) -> NoneType:
    _ = value
    return None

def borrowed(calls: ArcPointer[Int], drops: ArcPointer[Int]) raises:
    var anchor = RegisterVoidCapture(10, drops)
    def callback(value: Int) {var anchor^, calls}:
        calls[] += anchor.value + value
    var first = forward(callback, 1)
    comptime assert type_of(first) == Result[type_of(None), Never]
    assert_equal(first.is_ok(), True)
    assert_equal(drops[], 0)
    assert_equal(Capture.args(2).run(callback).is_ok(), True)
    assert_equal(calls[], 23)

def stored(calls: ArcPointer[Int], drops: ArcPointer[Int]) raises:
    var anchor = RegisterVoidCapture(20, drops)
    def callback(value: Int) {var anchor^, calls}:
        calls[] += anchor.value + value
    var wrapped = as_unary(callback^)
    comptime assert not conforms_to(type_of(wrapped), Copyable)
    var first = wrapped.call(1)
    comptime assert type_of(first) == type_of(None)
    _ = first
    assert_equal(drops[], 1)
    wrapped(2)
    assert_equal(calls[], 66)

def effects() raises:
    var calls = 0
    def never(value: Float64) raises Never {mut calls}:
        calls += Int(value)
    var empty = forward(never, Float64(3))
    comptime assert type_of(empty) == Result[type_of(None), Never]
    assert_equal(empty.is_ok(), True)
    _ = pipe(Float64(4), never)
    var stored_never = as_unary(never)
    stored_never.call(Float64(5))
    assert_equal(calls, 12)

    def raising(value: Int) raises RegisterVoidFailure {mut calls}:
        calls += 1
        if value < 0: raise RegisterVoidFailure(value)
    var failure = forward(raising, -7)
    comptime assert type_of(failure) == Result[type_of(None), RegisterVoidFailure]
    var code = 0
    try: _ = raise_on_err(failure^)
    except error: code = error.code
    assert_equal(code, -7)
    assert_equal(calls, 13)
    var stored_raising = as_unary(raising)
    try: _ = stored_raising.call(-8)
    except error: code = error.code
    assert_equal(code, -8)
    assert_equal(calls, 14)

    def boolean(value: Bool) {mut calls} -> None:
        calls += Int(value)
    var stored_bool = as_unary(boolean)
    stored_bool.call(True)
    stored_bool.call(False)
    assert_equal(calls, 15)

def main() raises:
    var a = as_unary(thin_pure)
    var b = as_unary(thin_never)
    var c = as_unary(thin_raising)
    a.call(1)
    b.call(2)
    var code = 0
    try: c.call(-3)
    except error: code = error.code
    assert_equal(code, -3)
    var none = forward(explicit_none, 4)
    comptime assert type_of(none) == Result[NoneType, Never]
    assert_equal(none.is_ok(), True)
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    borrowed(calls, drops)
    assert_equal(drops[], 1)
    stored(calls, drops)
    assert_equal(drops[], 2)
    effects()
