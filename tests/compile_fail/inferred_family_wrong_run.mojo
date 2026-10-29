# error: violated constraint
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def main():
    var recipe = pipeline(R.pure(1)).map(twice).get()
    _ = run[Reader[String]](recipe^, String("wrong"))
