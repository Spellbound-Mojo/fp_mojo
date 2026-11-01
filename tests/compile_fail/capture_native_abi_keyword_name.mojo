# error: function type conversions between closures not supported yet
# Mojo 1.2 also rejects this conversion without fp; the stored pointer's
# homogeneous keyword pack must be named kwargs in its explicit native type.
from fp.data import Capture
def f(var **options: Int) -> Int:
    return len(options)
def main():
    var pointer: def(var **options: Int) thin -> Int = f
    _ = Capture.kwargs(value=1).run(pointer)
