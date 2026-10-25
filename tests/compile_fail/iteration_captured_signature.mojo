# error: no matching function in call to 'map'
from fp.iteration import map
from std.iter import iter

def main():
    var offset = 2
    def mapping(var value: String) {var offset} -> Int: return value.byte_length() + offset
    _ = map(mapping, iter(range(3)))
