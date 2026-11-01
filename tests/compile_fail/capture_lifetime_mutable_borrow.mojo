# error: aliasing values
# error: in 'borrow' call
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var state=Token(1)
    _ = Capture.mutable(state).borrow(state)
