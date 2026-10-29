# error: cannot call function that may raise
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def fail(var value: Int) raises Int -> Int: raise value
def main():
    var recipe = pipeline(R.pure(1)).raising[Int]().map(fail).get()
    _ = run[R](recipe^, 0)
