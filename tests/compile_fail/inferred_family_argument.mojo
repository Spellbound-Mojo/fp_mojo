# error: no matching method in call to 'map'
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def main():
    _ = pipeline(R.pure(String("wrong"))).map(twice).get()
