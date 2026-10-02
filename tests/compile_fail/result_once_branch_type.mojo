from fp.algebra import flat_map, ResultFamily
# error: constraint
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    _ = flat_map[ResultFamily[type_of(Result[Int,Int](Ok(2))).Error]](Constant(Result[Int,String](Ok(1))), Result[Int,Int](Ok(2)))
