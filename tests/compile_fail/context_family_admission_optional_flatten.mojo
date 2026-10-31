# error: violated constraint
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily
from std.collections import Array
def main(): _ = pipeline(Optional(List[Int]([1]))).flatten().get()
