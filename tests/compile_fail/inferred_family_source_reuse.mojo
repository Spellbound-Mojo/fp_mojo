# error: uninitialized value
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def main():
    var recipe = R.pure(1)
    _ = pipeline(recipe^).map(twice).get()
    _ = run[R](recipe^, 0)
