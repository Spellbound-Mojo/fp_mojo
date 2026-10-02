# error: no matching function in call to 'filter'
# error: no matching function in call to 'filter_map'
# error: no matching function in call to 'flat_map'
from fp.iteration import filter, filter_map, flat_map
from std.iter import iter

def main():
    var offset = 1
    def predicate(value: Int) raises StopIteration {var offset} -> Bool:
        if value == offset: raise StopIteration()
        return True
    def optional(var value: Int) raises StopIteration {var offset} -> Optional[Int]:
        if value == offset: raise StopIteration()
        return Optional(value)
    def expand(var value: Int) raises StopIteration {var offset} -> List[Int]:
        if value == offset: raise StopIteration()
        return [value]
    _ = filter(predicate, iter(range(3)))
    _ = filter_map(optional, iter(range(3)))
    _ = flat_map(expand, iter(range(3)))
