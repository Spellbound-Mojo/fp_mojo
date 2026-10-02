# error: use of uninitialized value 'callback'
from fp.iteration import map
from std.iter import iter

@fieldwise_init
struct State(Movable):
    var offset: Int

def main():
    var state = State(2)
    def callback(var value: Int) {var state^} -> Int: return value + state.offset
    var mapped = map(callback^, iter(range(3)))
    print(callback(4))
    _ = mapped^
