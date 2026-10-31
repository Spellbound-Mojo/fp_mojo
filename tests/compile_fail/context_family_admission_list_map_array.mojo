# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily
from std.collections import Array
def f(var x:Int)->Int: return x
def main():
    var xs:Array[Int,2]=[1,2]
    _ = pipeline[ListFamily](xs^).map(f).get()
