# error: does not conform to trait 'Copyable & Deinitable'
from fp.functions import pipeline,piped
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,tuple_left
from std.collections import Array
from owned_fill_support import Box
def main():
    _=tuple_left(Box(1),range(2))
