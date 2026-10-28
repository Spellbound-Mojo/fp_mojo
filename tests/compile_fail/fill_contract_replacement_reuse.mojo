# error: use of uninitialized value 'value'
from algebra_support.fill_contracts import filled,discarded
from owned_fill_support import Box
from fp.algebra import ListFamily,OptionalFamily,ResultFamily
from fp.data import Result,Ok
def main():
    var value=Box(1)
    _=filled[OptionalFamily](Optional(1),value^)
    print(value.value)
