# error: no matching method in call to 'filter_map'
from fp.functions import pipeline
from std.collections import Array
def expansion_select(x: Int) -> Optional[Int]: return Optional(x)
def main():
    var xs: Array[Int, 2] = [1, 2]
    _ = pipeline(xs^).filter_map(expansion_select).get()
