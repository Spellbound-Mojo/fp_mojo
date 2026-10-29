# error: timeout fallback requires the same exact value and error types
from state_machine import timeout_to, pure
def main():
    _ = timeout_to(pure[Int](1), 10, pure[Int](String("wrong")))
