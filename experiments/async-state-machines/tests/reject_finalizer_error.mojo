# error: finalizer requires the same exact error type
from state_machine import guarantee, pure
def main():
    _ = guarantee(pure[Int](1), pure[String](2))
