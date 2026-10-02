# error: use of uninitialized value
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    var inactive = Constant(1)
    _ = Result[Int,Int](Ok(2)).fold_owned_once(Constant(2),inactive^)
    _ = inactive^
