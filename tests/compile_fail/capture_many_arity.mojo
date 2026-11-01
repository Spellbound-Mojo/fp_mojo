# error: no matching
from fp.data import Capture
def f(var a: Int, var b: Int) -> Int: return a+b
def main():
    _ = Capture[Never].args(1, 2, 3).run(f)
