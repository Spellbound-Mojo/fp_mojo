# error: no matching method
from fp.data import Result,Ok
from result_fold_receiver_support import Handler,Bare
def fail(value:Int) raises Int -> Int: raise value
def main():
    _=Result[Int,Int](Ok(1)).fold_owned(fail,Handler[Int,String](1,0))
