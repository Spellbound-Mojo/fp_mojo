# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily,OptionalFamily,NonEmptyListFamily
from std.collections import Array
def f(var x:Int)->Int: return x
def main(): _ = pipeline[NonEmptyListFamily](List[Int]([1])).map(f).get()
