# error: cannot call function that may raise 'X' in context that supports an error type of 'String'
from fp.functions import piped

def forward[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, //,
            F: def(var A) raises X -> B](var value: A, f: F) raises String -> B:
    return piped(value^).then(f).get()

@fieldwise_init
struct PipedError(Movable, Writable):
    var code: Int

def strict(value: Int) raises PipedError -> Int:
    raise PipedError(value)

def main() raises:
    _ = forward(17, strict)
