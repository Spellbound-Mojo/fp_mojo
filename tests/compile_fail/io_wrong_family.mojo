# error: violated constraint
from fp.effects import Reader
from fp.effects.io import run_io
from fp.algebra import pure
def main():
    _ = run_io(pure[Reader[Int]](1))
