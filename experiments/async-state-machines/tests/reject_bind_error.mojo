# error: constraint failed
# error: comptime assert Self.Next.Error == Self.Error
from state_machine import pure, bind, run
from composition import Add

def main():
    _ = run(bind(pure[String](7), Add()))
