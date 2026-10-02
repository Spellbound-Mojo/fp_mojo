from fp.algebra import map, ResultFamily
# error: use of uninitialized value
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    var callback = Constant(1)
    _ = map[ResultFamily[type_of(Result[Int,Int](Ok(2))).Error]](callback^, Result[Int,Int](Ok(2)))
    _ = callback^
