"""Compile-only, must be rejected: the classifier fires through a generic caller.

`relay` is generic over T; the assertion inside `admit` fires only when `main`
instantiates it with a type holding an `ArcPointer`. Never execute this program.
"""
from std.memory import ArcPointer
from thread_payload_check import admit, Shared


def relay[T: Movable](var value: T) -> T:
    return admit(value^)


def main():
    var shared = relay(Shared(ArcPointer(List[Int]())))
    print(len(shared.data[]))
