from fp.algebra import flat_map, ResultFamily
# error: constraint
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    _ = flat_map[ResultFamily[type_of(Result[Int,Int](Ok(2))).Error]](Result[Int,Int](Ok(2)), Constant(Result[Int,String](Ok(1))))
