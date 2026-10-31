# error: cannot call function that may raise
from fp.functions import pipeline
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def wrong[o: ImmOrigin](ref[o] owner: String) raises Pointer[String,o] -> Int:
    var local = String("local")
    return pipeline[Int]([1]).fold_left(Step[Int,Pointer[String,ImmOrigin(origin_of(local))]](1),0).get()
def main(): pass
