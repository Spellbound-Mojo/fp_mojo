# error: function type conversions
from fp.data import Capture

def wrong(a: Int, var b: String, var c: Int) -> Int: return a+c

def main():
    var pointer: def(Int, var String, var Int) thin -> Int = wrong
    _ = Capture[Never].args(1, String("x"), 3).run(pointer)
