# error: use of uninitialized value 'source'
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,fill
from std.collections import Array
from owned_fill_support import Box
def main():
    var source=Optional(1)
    _=pipeline(source^).fill(Box(1)).get()
    print(source.value())
