# error: constraint failed
# error: comptime assert Self.P.Error == Self.Q.Error
from state_machine import pure, both, run

def main():
    _ = run(both(pure[Int](7), pure[String](9)))
