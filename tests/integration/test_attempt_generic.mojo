"""Generic Results compose with public Result and lazy iterator operations."""
from fp.algebra import flat_map, ResultFamily
from fp.data import Capture, Result, raise_on_err
from std.testing import assert_equal

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R, mutable: Bool = True](
    function: F, mut first: A
) -> Result[R, Never]:
    return Capture.mutable(first).run(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R, mutable: Bool = True](
    function: F, mut first: A
) -> Result[R, X]:
    return Capture[X].mutable(first).run(function)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R, mutable: Bool = True](
    function: F, mut first: A
) -> Result[R, Never]:
    return capture[mutable=True](function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R, mutable: Bool = True](
    function: F, mut first: A
) -> Result[R, X]:
    return capture[mutable=True](function, first)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R, owned: Bool = True](
    function: F, var first: A
) -> Result[R, Never]:
    return Capture.take(first^).run(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R, owned: Bool = True](
    function: F, var first: A
) -> Result[R, X]:
    return Capture[X].take(first^).run(function)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R, owned: Bool = True](
    function: F, var first: A
) -> Result[R, Never]:
    return capture[owned=True](function, first^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R, owned: Bool = True](
    function: F, var first: A
) -> Result[R, X]:
    return capture[owned=True](function, first^)

def capture_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return Capture.take(first^).kwargs(**values^).run(function)

def capture_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return Capture[X].take(first^).kwargs(**values^).run(function)

def forward_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return capture_kwargs[owned=True](function, first^, **values^)

def forward_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return capture_kwargs[owned=True](function, first^, **values^)

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

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return Capture.mutable(first).take(second^).run(function)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return Capture[X].mutable(first).take(second^).run(function)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return capture[mut_owned=True](function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return capture[mut_owned=True](function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return Capture.take(first^).mutable(second).run(function)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return Capture[X].take(first^).mutable(second).run(function)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return capture[owned_mut=True](function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return capture[owned_mut=True](function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return Capture.mutable(first).mutable(second).run(function)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return Capture[X].mutable(first).mutable(second).run(function)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return capture[mut_mut=True](function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return capture[mut_mut=True](function, first, second)

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
    assert_equal(raise_on_err(forward[mut_owned=True](left, a, b)), 8)
    assert_equal(raise_on_err(forward[owned_mut=True](right, a, b)), 40)
    assert_equal(raise_on_err(forward[mut_mut=True](both, a, b)), 49)
    assert_equal(a, 10)
    assert_equal(b, 39)
    comptime assert Failure != OtherFailure
    var state = Value(0)
    for expected in range(1,4):
        var outer: Result[Result[Int, Failure], Failure] = forward[mutable=True](nested, state)
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
    var stopped: Result[Int, StopIteration] = forward[mutable=True](stop, scalar)
    assert_equal(stopped.is_err(), True)
    assert_equal(scalar, 6)
    var no_value = forward[mutable=True](empty, scalar)
    assert_equal(no_value.is_ok(), True)
    assert_equal(scalar, 8)
    var never: Result[String, Never] = forward[owned=True](pure_never, 9)
    assert_equal(raise_on_err(never^), "9")
    var calls = 0
    def parse_result(var text: String) {mut calls} -> Result[Int, Failure]:
        calls += 1
        return forward[owned=True](parse, text^)
    var values: List[String] = ["one", "bad", "unread"]
    var sequence = map(iter(values^), parse_result)
    var collected = collect_results(sequence^)
    assert_equal(calls, 2)
    var error_code = 0
    try: _ = raise_on_err(collected^)
    except error: error_code = error.code
    assert_equal(error_code, 7)
    var result = forward[owned=True](parse, String("four"))
    var combined = flat_map[ResultFamily[type_of(result).Error]](result^, success)
    var output: Int
    try: output = raise_on_err(combined^)
    except error: raise Error("unexpected failure")
    assert_equal(output, 5)
    var failed = forward[owned=True](parse, String("bad"))
    var mapped = failed^.map_err(remap)
    try: _ = raise_on_err(mapped^)
    except error: assert_equal(error.code, 107)
    var overlap = forward_kwargs[owned=True](first, Value(4), function=2, first=3, values=5)
    assert_equal(raise_on_err(overlap^), 14)
