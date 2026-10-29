# error: no matching function
from fp.algebra import map, pure
from fp.effects._async.family import Async
def wrong(value: Int) raises String -> Int:
    raise String("foreign error")
def main():
    _ = map[Async[Int]](wrong, pure[Async[Int]](1))
