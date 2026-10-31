"""Mojo 1.2 infers and propagates a generic Piped callback error unchanged."""
from fp.algebra import IdentityFamily
from fp.functions import pipeline
from std.testing import assert_equal, assert_true

def forward[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, //,
            F: def(var A) raises X -> B](var value: A, f: F) raises X -> B:
    return pipeline[IdentityFamily](value^).raising[X]().then(f).get()

@fieldwise_init
struct PipedError(Movable, Writable):
    var code: Int

def strict(value: Int) raises PipedError -> Int:
    raise PipedError(value)

def main() raises:
    var caught = False
    try:
        _ = forward(17, strict)
    except error:
        comptime assert type_of(error) == PipedError
        assert_equal(error.code, 17)
        caught = True
    assert_true(caught)
