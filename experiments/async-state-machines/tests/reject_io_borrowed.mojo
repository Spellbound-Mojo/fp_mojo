# error: no matching function in call to 'traverse'
from fp.algebra import traverse, ListFamily
from fp.effects._async.engine import Async
from state_machine import IO
def twice(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)
def main():
    var values: List[Int] = [1, 2, 3]
    _ = traverse[ListFamily, Async[Int]](twice, values^)
