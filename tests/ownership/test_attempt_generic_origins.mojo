"""Borrowed success and error payloads retain their exact native origin."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[R: Movable & Deinitable, //, F: def() -> R](function: F) -> Result[R, Never]:
    return attempt(function)

def capture[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](function: F) -> Result[R, X]:
    return attempt(function)

def forward[R: Movable & Deinitable, //, F: def() -> R](function: F) -> Result[R, Never]:
    return capture(function)

def forward[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](function: F) -> Result[R, X]:
    return capture(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](function: F, var value: A) -> Result[R, X]:
    return attempt(function, value^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](function: F, var value: A) -> Result[R, X]:
    return capture(function, value^)

def raise_view[V: Movable & Deinitable](var value: V) raises V -> Int:
    raise value^

def views(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def borrow() {view} -> View:
        return view
    var direct = borrow()
    assert_equal(Pointer(to=direct[0]) == Pointer(to=owner[0]), True)
    try: _ = raise_view[View](view)
    except error: assert_equal(Pointer(to=error[0]) == Pointer(to=owner[0]), True)
    var result: Result[View, Never] = forward(borrow)
    var returned = raise_on_err(result^)
    assert_equal(returned[0], 7)
    assert_equal(Pointer(to=returned[0]) == Pointer(to=owner[0]), True)
    var caught: Result[Int, View] = forward(raise_view[View], view)
    var code = 0
    try: _ = raise_on_err(caught^)
    except error:
        code = error[1]
        assert_equal(Pointer(to=error[0]) == Pointer(to=owner[0]), True)
    assert_equal(code, 11)

def main() raises:
    var owner: List[Int] = [7, 11]
    views(owner)
    assert_equal(owner, [7, 11])
