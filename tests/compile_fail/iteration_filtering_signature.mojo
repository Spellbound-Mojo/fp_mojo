# error: no matching function in call to 'filter'
# error: no matching function in call to 'filter_map'
from fp.iteration import filter, filter_map
from std.iter import iter

@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var offset = 1
    def consuming_predicate(var value: Token) {var offset} -> Bool: return value.value > offset
    def nonoptional(var value: Int) {var offset} -> Int: return value + offset
    var values = List[Token]()
    _ = filter(consuming_predicate, iter(values^))
    _ = filter_map(nonoptional, iter(range(3)))
