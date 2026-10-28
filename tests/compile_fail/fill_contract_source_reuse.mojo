# error: use of uninitialized value 'source'
from algebra_support.fill_contracts import filled,discarded
from owned_fill_support import Box
from fp.algebra import ListFamily,OptionalFamily,ResultFamily
from fp.data import Result,Ok
def main():
    var source=List[Int]([1])
    _=discarded[ListFamily](source^)
    print(len(source))
