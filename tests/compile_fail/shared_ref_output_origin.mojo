# error: cannot implicitly convert
from fp.callables import shared_ref,call_once
from shared_defaults_support import Factory
def wrong[o:ImmOrigin](ref[o] owner:List[Int]) -> Span[Int,o]:
    var local:List[Int]=[1]
    var factory=Factory(Span(local))
    return call_once(shared_ref(factory))
def main():
    var owner:List[Int]=[2]
    _=wrong(owner)
