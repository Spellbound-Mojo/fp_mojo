# error: constraint
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    var left = String('left')
    var right = String('right')
    _ = Result[Int,Int](Ok(2)).fold_owned_once(
        Constant[Int,Pointer[String,ImmOrigin(origin_of(left))]](1),
        Constant[Int,Pointer[String,ImmOrigin(origin_of(right))]](2))
