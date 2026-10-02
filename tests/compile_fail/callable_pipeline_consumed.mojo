# error: use of uninitialized value
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
@fieldwise_init
struct Token(Movable):
    var value: Int
def main():
    var state = Token(1)
    def count(var value: Int) {var state^} -> Int:
        state.value += 1
        return value + state.value
    var a = as_unary(count^)
    _ = count(1)
    _ = a(1)
