# error: cannot implicitly convert
from foundation import Borrowed
from state_machine import run


def escape() -> Span[Int, ImmUntrackedOrigin]:
    var owner = List[Int]([13, 17])
    var outcome = run(Borrowed(Pointer(to=owner), 0, False))
    return outcome.take()._take_ok()


def main():
    _ = escape()
