# error: cannot call function that may raise
from fp.data import Result,Ok,Err
from fp.callables import mut_ref
from result_fold_receiver_support import Handler,Bare
def wrong[o:ImmOrigin](ref[o] owner:String) raises Pointer[String,o] -> Int:
    var local=String("local")
    return Result[Int,Int](Ok(1)).fold(Handler[Int,Pointer[String,ImmOrigin(origin_of(local))]](2,0),Handler(2,0))
def main(): pass
