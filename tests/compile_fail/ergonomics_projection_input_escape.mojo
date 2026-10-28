# error: no matching
from fp.effects import Reader, asks

def escaped(value: List[Int]) -> Span[Int, origin_of(value)]:
    return Span(value)

def main():
    _ = asks[Reader[List[Int]], F=type_of(escaped)](escaped)
