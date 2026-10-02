# error: IterableOwned
from fp.iteration import flat_map
from std.iter import iter

@fieldwise_init
struct NonIterable(Movable):
    var value: Int

def main():
    var offset = 1
    def noninner(var value: Int) {var offset} -> NonIterable: return NonIterable(value + offset)
    _ = flat_map(noninner, iter(range(3)))
