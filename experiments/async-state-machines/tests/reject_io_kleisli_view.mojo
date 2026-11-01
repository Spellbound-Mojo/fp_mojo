# error: no matching method in call to 'traverse'
from fp.functions import kleisli
from fp.iteration import iterated
from fp.effects._async.engine import Async
from state_machine import IO
def twice(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)
def main():
    var chain = kleisli[Async[Int]](twice)
    var values: List[Int] = [1, 2, 3]
    _ = iterated(values^).traverse(chain)
