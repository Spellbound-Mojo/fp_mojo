# error: aliasing values
# error: in 'mutable' call
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var state=Token(1)
    _ = Capture.borrow(state).mutable(state)
