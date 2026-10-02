"""Generic Results compose with public Result and lazy iterator operations."""
from fp.algebra import flat_map, ResultFamily
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

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first^, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first^, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first^, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return capture(function, first^, **values^)

from fp.data import Ok, Err
from fp.iteration import map
from fp.data import collect_results
from std.iter import iter

@fieldwise_init
struct Value(Movable):
    var number: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

@fieldwise_init
struct OtherFailure(Movable):
    var code: Int

def nested(mut value: Value) raises Failure -> Result[Int, Failure]:
    value.number += 1
    if value.number == 3: raise Failure(30)
    return Result[Int, Failure](Err(Failure(10 * value.number)))

def stop(mut value: Int) raises StopIteration -> Int:
    value += 1
    raise StopIteration()

def empty(mut value: Int):
    value += 2

def pure_never(var value: Int) raises Never -> String:
    return String(value)

def parse(var text: String) raises Failure -> Int:
    if text == "bad": raise Failure(7)
    return text.byte_length()

def success(var value: Int) -> Result[Int, Failure]:
    return Result[Int, Failure](Ok(value + 1))

def remap(var error: Failure) -> OtherFailure:
    return OtherFailure(error.code + 100)

def first(var value: Value, /, var **options: Int) -> Int:
    for entry in options.items(): value.number += entry.value
    return value.number

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return attempt(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return attempt(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return capture(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return capture(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return attempt(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return attempt(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return capture(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return capture(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return attempt(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return attempt(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return capture(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return capture(function, first, second)

def left(mut a: Int, b: Int) -> Int:
    a += b
    return a

def right(a: Int, mut b: Int) -> Int:
    b *= a
    return b

def both(mut a: Int, mut b: Int) -> Int:
    a += 2
    b -= 1
    return a + b

def main() raises:
    var a = 3
    var b = 5
    assert_equal(raise_on_err(forward(left, a, b)), 8)
    assert_equal(raise_on_err(forward(right, a, b)), 40)
    assert_equal(raise_on_err(forward(both, a, b)), 49)
    assert_equal(a, 10)
    assert_equal(b, 39)
    comptime assert Failure != OtherFailure
    var state = Value(0)
    for expected in range(1,4):
        var outer: Result[Result[Int, Failure], Failure] = forward(nested, state)
        var native_error = 0
        var value_error = 0
        var inner_is_err = False
        try:
            var inner = raise_on_err(outer^)
            inner_is_err = inner.is_err()
            try: _ = raise_on_err(inner^)
            except error: value_error = error.code
        except error: native_error = error.code
        assert_equal(inner_is_err, expected < 3)
        assert_equal(value_error, 10 * expected if expected < 3 else 0)
        assert_equal(native_error, 30 if expected == 3 else 0)
        assert_equal(state.number, expected)
    var scalar = 5
    var stopped: Result[Int, StopIteration] = forward(stop, scalar)
    assert_equal(stopped.is_err(), True)
    assert_equal(scalar, 6)
    var no_value = forward(empty, scalar)
    assert_equal(no_value.is_ok(), True)
    assert_equal(scalar, 8)
    var never: Result[String, Never] = forward(pure_never, 9)
    assert_equal(raise_on_err(never^), "9")
    var calls = 0
    def parse_result(var text: String) {mut calls} -> Result[Int, Failure]:
        calls += 1
        return forward(parse, text^)
    var values: List[String] = ["one", "bad", "unread"]
    var sequence = map(parse_result, iter(values^))
    var collected = collect_results(sequence^)
    assert_equal(calls, 2)
    var error_code = 0
    try: _ = raise_on_err(collected^)
    except error: error_code = error.code
    assert_equal(error_code, 7)
    var result = forward(parse, String("four"))
    var combined = flat_map[ResultFamily[type_of(result).Error]](success, result^)
    var output: Int
    try: output = raise_on_err(combined^)
    except error: raise Error("unexpected failure")
    assert_equal(output, 5)
    var failed = forward(parse, String("bad"))
    var mapped = failed^.map_err(remap)
    try: _ = raise_on_err(mapped^)
    except error: assert_equal(error.code, 107)
    var overlap = forward(first, Value(4), function=2, first=3, values=5)
    assert_equal(raise_on_err(overlap^), 14)
