# error: race requires the same exact error type
from state_machine import race, pure
def main():
    _ = race(pure[Int](1), pure[String](2))
