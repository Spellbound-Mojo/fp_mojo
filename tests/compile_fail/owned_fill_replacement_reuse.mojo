# error: use of uninitialized value 'value'
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,fill
from std.collections import Array
from owned_fill_support import Box
def main():
    var value=Box(1)
    _=pipeline(Optional(1)).fill(value^).get()
    print(value.value)
