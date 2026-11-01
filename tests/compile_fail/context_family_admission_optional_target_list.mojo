# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily
from std.collections import Array
def f(var x:Int)->List[Int]: return List[Int]([x])
def main(): _ = pipeline(List[Int]([1])).traverse[OptionalFamily](f).get()
