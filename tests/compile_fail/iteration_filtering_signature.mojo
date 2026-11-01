# error: no matching function in call to 'filter'
from fp.iteration import filter
from std.iter import iter

@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var offset = 1
    def consuming_predicate(var value: Token) {var offset} -> Bool: return value.value > offset
    var values = List[Token]()
    _ = filter(iter(values^), consuming_predicate)
