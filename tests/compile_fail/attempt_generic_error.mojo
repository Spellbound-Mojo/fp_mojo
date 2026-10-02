# error: cannot implicitly convert
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

@fieldwise_init
struct First(Movable):
    var code: Int

@fieldwise_init
struct Second(Movable):
    var code: Int

def target() raises First -> Int: raise First(3)

def main():
    comptime assert First != Second
    var bad: Result[Int, Second] = forward(target)
    _ = bad^
