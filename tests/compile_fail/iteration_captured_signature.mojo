# error: no matching function in call to 'map'
# error: no matching function in call to 'scan_left'
from fp.iteration import map, scan_left
from std.iter import iter

def main():
    var offset = 2
    def mapping(var value: String) {var offset} -> Int: return value.byte_length() + offset
    def scanning(var acc: Int, var value: Int) {var offset} -> String: return String(acc + value + offset)
    _ = map(mapping, iter(range(3)))
    _ = scan_left(scanning, 0, iter(range(3)))
