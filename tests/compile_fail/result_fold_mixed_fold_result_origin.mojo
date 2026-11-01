# error: lacking evidence to prove correctness
from fp.data import Result,Ok
from result_fold_receiver_support import Handler,Bare
def identity[o:ImmOrigin](value:Pointer[Int,o])->Pointer[Int,o]: return value
def wrong[o:ImmOrigin](ref[o] owner:Int):
    var local=4
    _=Result[Pointer[Int,o],Int](Ok(Pointer(to=owner))).fold(identity[o],Handler(Pointer[Int,ImmOrigin(origin_of(local))](to=local),0))
def main(): pass
