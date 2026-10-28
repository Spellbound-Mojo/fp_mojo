# error: cannot call function that may raise
from fp.control import fori_loop
from fluent_fold_support import Step, Once, Bare
def wrong[o: ImmOrigin](ref[o] owner: String) raises Pointer[String,o] -> Int:
    var local = String("local")
    return fori_loop(0,1,Step[Int,Pointer[String,ImmOrigin(origin_of(local))]](1),0)
def main(): pass
