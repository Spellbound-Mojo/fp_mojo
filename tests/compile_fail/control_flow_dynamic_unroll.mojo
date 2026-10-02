# error: full unrolling requires static bounds
from fp.control import fori_loop
def body(var index: Int, var x: Int) -> Int: return x + index
def main():
    _ = fori_loop[unroll=0](0, 3, body, 0)
