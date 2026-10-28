# error: aliasing values passed mutably to 'self' argument and passed mutably to 'value' argument in 'take' call
from fp.data import Capture

@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var prefix = String("borrowed")
    var state = Token(1)
    _ = Capture().borrow(prefix).mutable(state).take(state^)
