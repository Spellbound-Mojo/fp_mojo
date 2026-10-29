# error: cannot implicitly convert
from fp.data import Left
from state_machine import race, pure, run
def escape[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, ImmUntrackedOrigin]:
    var outcome = run(race(pure[Int](Span(owner)), pure[Int](1)))
    return outcome.take()._take_ok().unwrap[Left[Span[Int, o]]]().into_payload()
def main():
    var owner = List[Int]([13, 17])
    _ = escape(owner)
