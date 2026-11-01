# error: aliasing values passed mutably
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var value = Token(3)
    def target(mut first: Token) {mut value} -> Int:
        value.value += first.value
        return value.value
    _ = Capture.mutable(value).run(target)
