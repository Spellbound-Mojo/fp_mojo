# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import IO
def main():
    var pending = pipeline(IO[Int].pure(3))
    _ = pending^.run_io()
    _ = pending^.run_io()
