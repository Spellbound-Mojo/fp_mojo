# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def wrong(owner: List[Int], other: List[Int]) -> Optional[Span[Int, origin_of(other)]]:
    comptime View = type_of(Span(owner))
    def keep(value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](keep)
    return pipeline(Span(owner)).then(chain).get()

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
