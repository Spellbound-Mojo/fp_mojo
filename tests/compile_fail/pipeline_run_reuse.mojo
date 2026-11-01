# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import Reader
def main():
    var pending = pipeline(Reader[Int].pure(3))
    _ = pending^.run(0)
    _ = pending^.run(0)
