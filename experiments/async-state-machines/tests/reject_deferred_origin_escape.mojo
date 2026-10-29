# error: cannot implicitly convert
from state_machine import Deferred
from async_coordination import value

def escape[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, ImmUntrackedOrigin]:
    var deferred = Deferred[Span[Int, o]]()
    _ = value(deferred.complete[Int](Span(owner)))
    return value(deferred.get[Int]())

def main():
    var owner = List[Int]([13, 17])
    _ = escape(owner)
