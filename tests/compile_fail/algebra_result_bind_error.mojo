# error: flat_map: callback must return the same Result family
from fp.algebra import flat_map, ResultFamily
from fp.callables import as_unary
from fp.data import Result, Ok

def wrong_error(var value:Int)->Result[Int,String]:
    return Result[Int,String](Ok(value))

def main():
    _=flat_map[ResultFamily[Int]](as_unary(wrong_error),Result[Int,Int](Ok(1)))
