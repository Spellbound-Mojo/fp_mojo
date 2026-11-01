# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily
from std.collections import Array
def f(var a:Int,var b:Int)->Int: return a+b
def main(): _ = pipeline(Optional(1)).map2(List[Int]([2]),f).get()
