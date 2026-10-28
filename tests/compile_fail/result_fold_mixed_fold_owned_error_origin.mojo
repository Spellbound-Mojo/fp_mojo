# error: lacking evidence to prove correctness
from fp.data import Result,Ok
from result_fold_receiver_support import Handler,Bare
def fail[o:ImmOrigin](value:Pointer[Int,o]) raises Pointer[Int,o] -> Int: raise value
def wrong[o:ImmOrigin](ref[o] owner:Int):
    var local=4
    _=Result[Pointer[Int,o],Int](Ok(Pointer(to=owner))).fold_owned(fail[o],Handler[Int,Pointer[Int,ImmOrigin(origin_of(local))]](1,0))
def main(): pass
