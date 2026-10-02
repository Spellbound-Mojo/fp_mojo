# error: fp.match: None has no clause that cannot decline
import fp

def main():
    var o = Optional(3)
    _ = fp.match(o, lambda (x: Int) -> Int: x)
