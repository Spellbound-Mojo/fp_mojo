# error: aliasing values passed mutably
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
def target(mut first: Token, var second: Token) -> Int: return first.value + second.value
def main():
    var value = Token(3)
    _ = Capture[Never].mut_owned(target).run(value, value^)
