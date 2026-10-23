# error: no matching method in call to 'filter'
from fp.functions import piped
from std.collections import Array
def select(x: Int) -> Bool: return x > 0
def main():
    var xs: Array[Int, 2] = [1, 2]
    _ = piped(xs^).filter(select).get()
