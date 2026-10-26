# error: no matching method in call to 'map'
from fp.algebra import ArrayFamily
from fp.functions import pipeline
from std.collections import Array
def inc(var value: Int) -> Int: return value + 1
def main():
    var values: Array[Int, 2] = [1, 2]
    _ = pipeline[ArrayFamily[3]](values^).map(inc)
