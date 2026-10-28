# error: uninitialized
from fp.functions import pipeline, as_unary
from fp.effects import Reader, run

def double(var value: Int) -> Int: return value * 2
def main():
    var callback = as_unary(double)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(1)).map(callback).get()
    var function = callback^.into_function()
    _ = function(2)
    _ = run[Reader[Int]](pending^, 0)
