"""Forward a generic pipeline without spelling its intermediate result types."""
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var
from std.testing import assert_equal


def forward[R: Movable & Deinitable, E: Movable & Deinitable,
            A: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> R where Fs.length >= 2:
    # Check nominal type identity before the native ownership-preserving transfer.
    var result = pipe[E=E](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


@fieldwise_init
struct Failure(Movable):
    var code: Int


def label(var value: Int) raises Failure -> String:
    if value < 0: raise Failure(value)
    return String(value)


def size(value: String) raises Never -> Int:
    return value.byte_length()


def main() raises:
    var first = as_unary(label)
    var last = as_unary(size)
    var result: Int
    try: result = forward[Int, Failure](123, first, last)
    except error: raise Error(String(error.code))
    assert_equal(result, 3)
    var caught = False
    try: _ = forward[Int, Failure](-7, first, last)
    except error:
        caught = True
        assert_equal(error.code, -7)
    assert_equal(caught, True)
    print("generic pipeline: 3; error: -7")
