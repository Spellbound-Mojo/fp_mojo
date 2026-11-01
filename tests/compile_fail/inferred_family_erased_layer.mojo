# error: no matching method in call to 'map'
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def main():
    comptime T = ResultT[R, String]
    _ = pipeline(T.pure(1)).map(twice).get()
