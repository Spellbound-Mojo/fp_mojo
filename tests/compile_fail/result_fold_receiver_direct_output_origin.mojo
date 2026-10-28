# error: cannot implicitly convert
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def wrong[o: ImmOrigin](ref[o] owner: String) -> Pointer[String,o]:
    var local = String("local")
    return invoke_borrowed_once[Never](1,Handler(Pointer(to=local),0))
def main(): pass
