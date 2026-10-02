# error: no matching function in call to 'map'
# error: no matching function in call to 'scan_left'
from fp.iteration import map, scan_left
from std.iter import iter

def main():
    var boundary = 2
    def mapping(var value: Int) raises StopIteration {var boundary} -> Int:
        if value == boundary: raise StopIteration()
        return value
    def scanning(var acc: Int, var value: Int) raises StopIteration {var boundary} -> Int:
        if value == boundary: raise StopIteration()
        return acc + value
    _ = map(mapping, iter(range(3)))
    _ = scan_left(scanning, 0, iter(range(3)))
