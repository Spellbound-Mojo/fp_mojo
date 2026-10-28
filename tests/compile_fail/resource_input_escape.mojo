# error: no matching
from fp.effects.resources import resource

def acquire() -> List[Int]: return [1]
def release(var value: List[Int]): pass
def escape(value: List[Int]) -> Span[Int, origin_of(value)]: return Span(value)
def main():
    _ = resource[Error](acquire, release).use[F=type_of(escape)](escape)
