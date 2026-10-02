"""Chained pipelines: no stage limit, one inferred call per stage, exact errors."""
from fp.functions import piped, Piped, partial, flow, as_unary
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true


@fieldwise_init
struct PipedParseError(Movable, Writable):
    var text: String


def parse(text: String) raises PipedParseError -> Int:
    try:
        return atol(text)
    except:
        raise PipedParseError(text)


def inc(value: Int) -> Int:
    return value + 1


def owned_inc(var value: Int) -> Int:
    return value + 1


def add(a: Int, b: Int) -> Int:
    return a + b


def label(value: Int) -> String:
    return "value = " + String(value)


def length(text: String) -> Int:
    return text.byte_length()


def checked(value: Int) -> Result[Int, String]:
    if value < 0:
        return Err(String("negative"))
    return Ok(value)


def stages() raises:
    assert_equal(piped(7).get(), 7)
    assert_equal(piped(1).then(inc).get(), 2)
    # Twelve stages, past the eight that pipe takes as plain functions, with
    # read and owned parameters and changing types.
    var long = piped(0).then(inc).then(owned_inc).then(inc).then(owned_inc).then(inc) \
        .then(owned_inc).then(inc).then(owned_inc).then(inc).then(label).then(length).then(inc).get()
    assert_equal(long, 10)  # nine increments, len("value = 9") == 9, then one more
    comptime assert type_of(piped(1).then(label)) == Piped[String]


def order_and_closures() raises:
    var trace = List[Int]()
    var bias = 100
    def first(value: Int) {mut trace} -> Int:
        trace.append(1)
        return value * 2
    def second(value: Int) {mut trace, bias} -> Int:
        trace.append(2)
        return value + bias
    var out = piped(5).then(first).then(second).then(first).get()
    assert_equal(out, 220)
    var expected: List[Int] = [1, 2, 1]
    assert_equal(trace, expected)


def library_values() raises:
    var offset = 3
    def shift(value: Int) {imm offset} -> Int:
        return value + offset
    var out = piped(1).then(partial(add, 10)).then(flow(inc, inc)).then(as_unary(shift)).then(label).get()
    assert_equal(out, "value = 16")


def errors() raises:
    assert_equal(piped(String("41")).then(parse).then(inc).get(), 42)
    var after = 0
    def counted(value: Int) {mut after} -> Int:
        after += 1
        return value
    var text = String()
    try:
        _ = piped(String("abc")).then(parse).then(counted).get()
    except error:
        comptime assert type_of(error) == PipedParseError
        text = error.text
    assert_equal(text, "abc")
    assert_equal(after, 0)  # the stage after the failure never runs


def results_pass_whole() raises:
    var failed = piped(-1).then(checked).get()
    assert_true(failed.is_err())
    var passed = piped(4).then(checked).get()
    assert_equal(passed^.raise_on_err(), 4)


def forward[A: Movable & Deinitable, B: Movable & Deinitable, C: Movable & Deinitable, //,
            F: def(var A) -> B, G: def(var B) -> C](var value: A, f: F, g: G) -> C:
    return piped(value^).then(f).then(g).get()


def forward_raising[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, //,
                    F: def(var A) raises X -> B](var value: A, f: F) raises X -> B:
    return piped(value^).then[E=X](f).get()


def generic_forwarding() raises:
    assert_equal(forward(1, inc, label), "value = 2")
    var step = 5
    def plus(value: Int) {imm step} -> Int:
        return value + step
    assert_equal(forward(1, plus, inc), 7)
    assert_equal(forward_raising(String("8"), parse), 8)
    var text = String()
    try:
        _ = forward_raising(String("x"), parse)
    except error:
        comptime assert type_of(error) == PipedParseError
        text = error.text
    assert_equal(text, "x")


def main() raises:
    stages()
    order_and_closures()
    library_values()
    errors()
    results_pass_whole()
    generic_forwarding()
    print("piped: chained stages, closures, library values and exact errors")
