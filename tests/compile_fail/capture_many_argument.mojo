# error: no matching
from fp.data import Capture
def f(var a: Int, var b: Int, var c: String) -> Int: return a+b+c.byte_length()
def main():
    _ = Capture[Never].args(1, 2, 3).run(f)
