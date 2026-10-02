# error: fp.match: clause 0 takes String for the subject
import fp

def main():
    var o = Optional(3)
    _ = fp.match(o, lambda (x: String) -> Int: 1, lambda (n: NoneType) -> Int: 0)
