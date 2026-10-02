# error: use of uninitialized value 'value'
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

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


@fieldwise_init
struct Token(Movable):
    var value: Int

def take(var value: Token) -> Token: return value^
def main():
    var value = Token(7)
    _ = forward(take, value^)
    _ = value.value
