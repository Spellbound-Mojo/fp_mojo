# error: value passed to 'fallback' cannot be converted from 'IO[String, Int]' to 'IO[Int, Int]'
from state_machine import IO
from fp._internal.time import Duration
def main():
    _ = IO[Int, Int].pure(1).timeout_to(Duration(), IO[String, Int].pure(String("wrong")))
