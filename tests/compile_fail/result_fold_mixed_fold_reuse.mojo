# error: use of uninitialized value
from fp.data import Result,Ok
from result_fold_receiver_support import Handler,Bare
def identity(value:Int)->Int:return value
def main():
    var handler=Handler(1,0)
    _=Result[Int,Int](Ok(1)).fold(identity,handler^)
    _=handler.calls
