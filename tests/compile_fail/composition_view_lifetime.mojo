# error: uninitialized
from fp.functions import pipeline, flow
from fp.effects import Reader, run

def add(value: Int) -> Int: return value + 1
def double(value: Int) -> Int: return value * 2
def main():
    var chain = flow(add, double)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(1)).map(chain).get()
    var moved = chain^
    _ = moved(2)
    _ = run[Reader[Int]](pending^, 0)
