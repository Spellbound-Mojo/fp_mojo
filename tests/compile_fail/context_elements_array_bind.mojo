# error: no matching method in call to 'flat_map'
from fp.functions import pipeline
from std.collections import Array
def pair(var value: Int) -> Array[Int, 2]: return [value, value]
def main():
    var values: Array[Int, 2] = [1, 2]
    _ = pipeline(values^).elements().flat_map(pair)
