# error: constraint
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def wrong[o: ImmOrigin](ref[o] owner: String) raises Pointer[String,o] -> Int:
    var local = String("local")
    return invoke_borrowed_once[Pointer[String,o]](1,Handler[Int,Pointer[String,ImmOrigin(origin_of(local))]](1,0))
def main(): pass
