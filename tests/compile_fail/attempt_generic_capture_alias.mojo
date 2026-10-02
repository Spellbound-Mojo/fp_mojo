# error: aliasing values passed mutably
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R](
    function: F, mut first: A
) -> Result[R, Never]:
    return attempt(function, first)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R](
    function: F, mut first: A
) -> Result[R, X]:
    return attempt(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R](
    function: F, mut first: A
) -> Result[R, Never]:
    return capture(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R](
    function: F, mut first: A
) -> Result[R, X]:
    return capture(function, first)


@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var value = Token(3)
    def target(mut first: Token) {mut value} -> Int:
        value.value += first.value
        return value.value
    _ = forward(target, value)
