# error: constraint
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    _ = Result[Int,Int](Ok(2)).fold_owned_once(Constant[Int,Int](1),Constant[Int,String](2))
