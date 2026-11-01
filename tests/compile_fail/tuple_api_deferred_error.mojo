# error: cannot call function that may raise
from fp.effects import Reader, run
from fp.functions import pipeline
from algebra_support.tuple_contracts import attached_right
def fail(var value: Int) raises Int -> Int:
    raise value
def main():
    comptime R = Reader[Int]
    var source = pipeline[R](R.pure(19)).raising[Int]().map(fail).get()
    var pending = attached_right[R](source^, 7)
    _ = run[R](pending^, 0)
