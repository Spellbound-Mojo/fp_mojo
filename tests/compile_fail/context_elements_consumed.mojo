# error: use of uninitialized value
from fp.functions import pipeline
from std.collections import Array
def main():
    var values: Array[String, 1] = ["value"]
    var source = pipeline(values^)
    _ = source^.elements()
    _ = source^.get()
