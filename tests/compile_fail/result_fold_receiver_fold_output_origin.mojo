# error: cannot implicitly convert
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def wrong[o: ImmOrigin](ref[o] owner: String) -> Pointer[String,o]:
    var local = String("local")
    return Result[Int,Int](Ok(1)).fold_owned_once(Handler(Pointer[String,ImmOrigin(origin_of(local))](to=local),0),Handler(Pointer[String,ImmOrigin(origin_of(local))](to=local),0))
def main(): pass
