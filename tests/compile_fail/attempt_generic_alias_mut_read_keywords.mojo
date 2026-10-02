# error: aliasing values passed mutably
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)


@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut first: Token, second: Token, /, var **values: Int) -> Int:
    first.value += second.value
    return first.value

def main():
    var value = Token(3)
    _ = forward(target, value, value, one=7)
