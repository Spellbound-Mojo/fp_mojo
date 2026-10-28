# error: cannot call function that may raise
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def wrong[o: ImmOrigin](ref[o] owner: String) raises Pointer[String,o] -> Int:
    var local = String("local")
    var body = Body(0)
    return while_loop_mut(Predicate[Bool,Pointer[String,ImmOrigin(origin_of(local))]](False,0),body,0)
def main(): pass
