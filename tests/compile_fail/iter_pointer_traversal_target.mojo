# error: no matching
from fp.iteration import iterated
from fp.algebra import ResultFamily
def callback(var value: Int) -> Optional[Int]: return Optional(value)
def main():
    var pointer: def(var Int) thin -> Optional[Int] = callback
    _ = iterated(range(2)).traverse[ResultFamily[String]](pointer)
