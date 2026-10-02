# error: use of uninitialized value
from fp.functions import identity

@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var source = Token(3)
    var moved = identity(source^)
    print(source.value)
    print(moved.value)
