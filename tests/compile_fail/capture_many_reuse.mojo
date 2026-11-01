# error: use of uninitialized value
from fp.data import Capture
def f(var a: Int, var b: Int, var c: Int) -> Int: return a+b+c
def main():
    var pending = Capture[Never].args(1,2,3)
    _ = pending^.run(f)
    _ = pending^.run(f)
