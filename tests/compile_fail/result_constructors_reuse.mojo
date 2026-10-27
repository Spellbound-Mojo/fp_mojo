# error: use of uninitialized value
from fp.data import ok
def main():
    var value: List[Int] = [1,2]
    _ = ok[String](value^)
    _ = value^
