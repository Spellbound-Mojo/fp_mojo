# error: call to 'delay'
from fp.effects.async_runtime import IO
def main():
    var captured = 41
    def add() {captured} -> Int:
        return captured + 1
    _ = IO[Int, Int].delay(add)
