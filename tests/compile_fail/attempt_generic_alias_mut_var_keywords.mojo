from fp.data import mut_owned_kwargs
# error: aliasing values passed mutably
from fp.data import Result, attempt_kwargs, raise_on_err
from std.testing import assert_equal

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return attempt_kwargs(mut_owned_kwargs(function), first, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return attempt_kwargs(mut_owned_kwargs(function), first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return capture(function, first, second^, **values^)


@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut first: Token, var second: Token, /, var **values: Int) -> Int:
    first.value += second.value
    return first.value

def main():
    var value = Token(3)
    _ = forward(target, value, value^, one=7)
