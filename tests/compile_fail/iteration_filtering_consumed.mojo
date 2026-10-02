# error: use of uninitialized value 'predicate'
# error: use of uninitialized value 'optional'
# error: use of uninitialized value 'expand'
from fp.iteration import filter, filter_map, flat_map
from std.iter import iter

@fieldwise_init
struct State(Movable):
    var value: Int

def main():
    var first = State(2)
    def predicate(value: Int) {var first^} -> Bool: return value > first.value
    _ = filter(predicate^, iter(range(3)))
    _ = predicate(1)
    var second = State(2)
    def optional(var value: Int) {var second^} -> Optional[Int]: return Optional(value + second.value)
    _ = filter_map(optional^, iter(range(3)))
    _ = optional(1)
    var third = State(2)
    def expand(var value: Int) {var third^} -> List[Int]: return [value, third.value]
    _ = flat_map(expand^, iter(range(3)))
    _ = expand(1)
