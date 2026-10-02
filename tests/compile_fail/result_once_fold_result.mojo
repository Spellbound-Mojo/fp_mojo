# error: constraint
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    _ = Result[Int,Int](Ok(2)).fold_owned_once(Constant(2),Constant(String('bad')))
