# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import IO
def main():
    var cleanup = IO[Int].pure(4)
    var pending = pipeline(IO[Int].pure(3)).guarantee(cleanup^)
    _ = cleanup^
    _ = pending^.run_io()
