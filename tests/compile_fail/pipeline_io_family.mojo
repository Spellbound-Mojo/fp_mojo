# error: no matching
from fp.functions import pipeline
from fp.effects import IO
from fp.algebra import IdentityFamily
def main(): _ = pipeline[IdentityFamily](IO[Int].pure(3)).run_io()
