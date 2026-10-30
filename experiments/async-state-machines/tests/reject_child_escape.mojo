# error: cannot implicitly convert
from fp.effects import Outcome
from state_machine import run
from foundation import Borrowed, both

def escape() -> Outcome[Tuple[Span[Int, ImmUntrackedOrigin], Span[Int, ImmUntrackedOrigin]], Span[Int, ImmUntrackedOrigin]]:
    var owner = List[Int]([13, 17])
    return run(both(Borrowed(Pointer(to=owner), 0, False), Borrowed(Pointer(to=owner), 0, False)))

def main():
    _ = escape()
