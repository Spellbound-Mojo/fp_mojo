# error: no matching function in call to 'attempt'
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Fail(Movable):
    var code: Int
def main():
    var offset=1
    def callback(var value: Token)   -> Int:
        return value.value
    var value=Token(3)
    _ = attempt[mutable=True, F=type_of(callback)](callback, value)
    _ = offset
