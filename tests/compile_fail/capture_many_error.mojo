# error: no matching
from fp.data import Capture
def f(var a: Int, var b: Int, var c: Int) raises String -> Int: raise String("wrong")
def main():
    _ = Capture[Int].args(1, 2, 3).run(f)
