# error: use of uninitialized value
from fp.data import ok
from fp.functions import pipeline
def main():
    var source = pipeline(ok[Never](List[Int]([1])))
    _ = source^.raise_on_err()
    _ = source^
