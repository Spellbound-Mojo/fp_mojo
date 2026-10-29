# error: cannot implicitly convert
# error: but the second value is 'ImmUntrackedOrigin'
from fp.effects import Outcome
from nursery_origins import borrowed_group

def escape() -> Outcome[List[Span[Int, ImmUntrackedOrigin]], Span[Int, ImmUntrackedOrigin]]:
    var owner = List[Int]([13, 17])
    return borrowed_group(owner, False)

def main():
    _ = escape()
