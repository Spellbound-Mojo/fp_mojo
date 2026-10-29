# error: no matching method in call to 'tuple_left'
from fp.functions import pipeline,piped
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,tuple_left
from std.collections import Array
from owned_fill_support import Box
def main():
    _=piped(List[Int]([1,2])).tuple_left[ListFamily](Box(1))
