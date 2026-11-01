# error: no matching
from fp.data import Capture
def f(var a: Int, mut b: Int, var c: Int) -> Int: return a+b+c
def main():
    _ = Capture[Never].args(1, 2, 3).run(f)
