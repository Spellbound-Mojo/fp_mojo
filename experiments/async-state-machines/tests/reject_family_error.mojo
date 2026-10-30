# error: no matching function
from fp.algebra import map, pure
from fp.callables import as_unary
from fp.effects._async.engine import Async
def wrong(value: Int) raises String -> Int:
    raise String("foreign error")
def main():
    _ = map[Async[Int]](pure[Async[Int]](1), as_unary(wrong))
