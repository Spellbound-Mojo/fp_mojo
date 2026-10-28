# error: uninitialized
from fp.functions import pipeline, partial
from fp.effects import Reader, run

def above(limit: Int, value: Int) -> Bool: return value > limit
def main():
    var predicate = partial(above, 2)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(3)).tap_each(predicate).get()
    var moved = predicate^
    _ = moved(4)
    _ = run[Reader[Int]](pending^, 0)
