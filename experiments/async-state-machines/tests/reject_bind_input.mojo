# error: constraint failed
# error: comptime assert Self.F.Arg == Self.P.Value
from state_machine import pure, bind, run
from composition import Transfer
from foundation import Failure
from std.memory import ArcPointer

def main():
    _ = run(bind(pure[Failure](7), Transfer(ArcPointer(0), False)))
