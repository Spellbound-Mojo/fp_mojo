# error: cannot implicitly convert
from fp.effects import Outcome
from state_machine import callback, pure, run
from callback_origins import BorrowRegister

def registered[o: ImmOrigin](ref[o] owner: List[Int]) -> Outcome[Span[Int, o], Span[Int, o]]:
    var unit: NoneType = None
    return run(callback(BorrowRegister(Pointer(to=owner), False), pure[Span[Int, o]](unit)))

def escape() -> Outcome[Span[Int, ImmUntrackedOrigin], Span[Int, ImmUntrackedOrigin]]:
    var owner = List[Int]([13, 17])
    return registered(owner)

def main():
    _ = escape()
