# error: cannot implicitly convert
# error: but the second value is 'ImmUntrackedOrigin'
from state_machine import Spawner
from foundation import Borrowed
from nursery_origins import retained

def escape() -> Spawner[Borrowed[ImmUntrackedOrigin]]:
    var owner = List[Int]([13, 17])
    return retained(owner)

def main():
    _ = escape()
