# error: value passed to 'other' cannot be converted from 'IO[Int, String]' to 'IO[Int, Int]'
from state_machine import IO, run

def main():
    _ = run(IO[Int, Int].pure(7).both(IO[Int, String].pure(9)))
