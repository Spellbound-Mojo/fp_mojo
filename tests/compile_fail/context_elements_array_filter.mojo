# error: no matching method in call to 'filter'
from fp.functions import pipeline
from std.collections import Array
def positive(value: Int) -> Bool: return value > 0
def main():
    var values: Array[Int, 2] = [1, 2]
    _ = pipeline(values^).elements().filter(positive)
