# error: origin_of(local)
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return attempt(function)

def capture[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return attempt(function)

def forward[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return capture(function)

def forward[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return capture(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var first: A
) -> Result[R, Never]:
    return attempt(function, first^)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](
    function: F, var first: A
) -> Result[R, X]:
    return attempt(function, first^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var first: A
) -> Result[R, Never]:
    return capture(function, first^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](
    function: F, var first: A
) -> Result[R, X]:
    return capture(function, first^)

def raise_view[V: Movable & Deinitable](var value: V) raises V -> Int:
    raise value^

def check(anchor: List[Int], local: List[Int]):
    var anchor_view = Span(anchor)
    var local_view = Span(local)
    comptime Local = type_of(local_view)
    def borrow() {local_view} -> Local: return local_view
    var bad: Result[type_of(anchor_view), Never] = forward(borrow)
    _ = bad^

def main():
    var owner: List[Int] = [3]
    var local: List[Int] = [7, 11]
    check(owner, local)
