# error: invalid call to 'tuple_left'
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,tuple_left
from std.collections import Array
from owned_fill_support import Box
def main():
    _=pipeline(List[Int]([1,2])).tuple_left(Box(1))
