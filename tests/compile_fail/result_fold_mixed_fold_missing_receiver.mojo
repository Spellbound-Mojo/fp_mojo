# error: Result fold:
from fp.data import Result,Ok
from result_fold_receiver_support import Handler,Bare
def identity(value:Int)->Int:return value
def main():
    _=Result[Int,Int](Ok(1)).fold(identity,Bare())
