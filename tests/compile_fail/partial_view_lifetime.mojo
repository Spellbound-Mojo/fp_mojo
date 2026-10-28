# error: uninitialized
from fp.functions import pipeline, partial
from fp.effects import Reader, run

def scale(factor: Int, value: Int) -> Int: return factor * value
def main():
    var callback = partial(scale, 3)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(1)).map(callback).get()
    var moved = callback^
    _ = moved(2)
    _ = run[Reader[Int]](pending^, 0)
