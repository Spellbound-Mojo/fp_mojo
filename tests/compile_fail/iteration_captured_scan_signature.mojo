# error: no matching function in call to 'scan_left'
from fp.iteration import scan_left
from std.iter import iter

def main():
    var offset = 2
    def scanning(var acc: Int, var value: Int) {var offset} -> String:
        return String(acc + value + offset)
    _ = scan_left(iter(range(3)), 0, scanning)
