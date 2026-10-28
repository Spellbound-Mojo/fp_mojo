# error: cannot implicitly convert
from fp.callables import shared_ref
from fp.data import Result,attempt_once
from shared_ref_support import Failure
def wrong[o:ImmOrigin](ref[o] owner:List[Int]) -> Result[Int,Span[Int,o]]:
    var local:List[Int]=[1]
    var factory=Failure(Span(local))
    return attempt_once(shared_ref(factory))
def main():
    var owner:List[Int]=[2]
    _=wrong(owner)
