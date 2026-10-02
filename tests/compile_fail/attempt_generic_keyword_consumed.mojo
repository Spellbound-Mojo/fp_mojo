# error: use of uninitialized value
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var **kwargs: K) -> R](
    function: F, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, **values^)

def capture[K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var **kwargs: K) raises X -> R](
    function: F, /, var **values: K
) -> Result[R, X]:
    return attempt(function, **values^)

def forward[K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var **kwargs: K) -> R](
    function: F, /, var **values: K
) -> Result[R, Never]:
    return capture(function, **values^)

def forward[K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var **kwargs: K) raises X -> R](
    function: F, /, var **values: K
) -> Result[R, X]:
    return capture(function, **values^)


@fieldwise_init
struct Token(Movable):
    var value: Int

def target(var **values: Token) -> Int:
    return len(values)

def main():
    var token = Token(7)
    _ = forward(target, value=token^)
    _ = token.value
