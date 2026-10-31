# error: does not conform to trait 'Copyable & Deinitable'
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,fill
from std.collections import Array
from owned_fill_support import Box
def main():
    _=iterated(range(2)).fill(Box(1))
