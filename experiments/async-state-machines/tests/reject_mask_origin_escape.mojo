# error: cannot implicitly convert
from state_machine import uncancelable, pure, run
def escape[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, ImmUntrackedOrigin]:
    var outcome = run(uncancelable(pure[Int](Span(owner))))
    return outcome.take()._take_ok()
def main():
    var owner = List[Int]([13, 17])
    _ = escape(owner)
