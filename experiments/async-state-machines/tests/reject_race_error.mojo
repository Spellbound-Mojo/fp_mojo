# error: value passed to 'other' cannot be converted from 'IO[Int, String]' to 'IO[Int, Int]'
from state_machine import IO
def main():
    _ = IO[Int, Int].pure(1).race(IO[Int, String].pure(2))
