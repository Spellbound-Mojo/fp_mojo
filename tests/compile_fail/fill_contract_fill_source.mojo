# error: violated constraint
from algebra_support.fill_contracts import filled,discarded
from owned_fill_support import Box
from fp.algebra import ListFamily,OptionalFamily,ResultFamily
from fp.data import Result,Ok
def main():
    _=filled[OptionalFamily](Result[Int,Int](Ok(1)),3)
