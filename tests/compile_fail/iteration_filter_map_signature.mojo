# error: no matching function in call to 'filter_map'
from fp.iteration import filter_map
from std.iter import iter

def main():
    var offset = 1
    def nonoptional(var value: Int) {var offset} -> Int: return value + offset
    _ = filter_map(nonoptional, iter(range(3)))
