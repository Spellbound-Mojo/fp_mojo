# error: no matching
from fp.iteration import iterated
from fp.algebra import ResultFamily
def present(var value: Int) -> Optional[Int]: return Optional(value)
def main():
    _ = iterated(List[Int]([1])).traverse[ResultFamily[String]](present)
