# error: constraint
from fp.data import Result,Ok,Err
from fp.callables import mut_ref
from result_fold_receiver_support import Handler,Bare
def main():
    _=Result[Int,Int](Ok(1)).fold(Handler[Int,Never,String](2,0),Handler(2,0))
