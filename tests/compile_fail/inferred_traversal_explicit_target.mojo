# error: no matching
from fp.functions import pipeline
from fp.algebra import ResultFamily
def present(var value: Int) -> Optional[Int]: return Optional(value)
def main():
    _ = pipeline(List[Int]([1])).traverse[ResultFamily[String]](present)
