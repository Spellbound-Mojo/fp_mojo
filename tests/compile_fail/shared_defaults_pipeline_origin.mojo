# error: lacking evidence to prove correctness
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from shared_defaults_support import Factory
def wrong[o:ImmOrigin](ref[o] owner:Int):
    var local=4
    var factory=Factory(Pointer[Int,ImmOrigin(origin_of(local))](to=local))
    _=pipeline(Result[Pointer[Int,o],Int](Err(1))).get_or_else(factory)
def main(): pass
