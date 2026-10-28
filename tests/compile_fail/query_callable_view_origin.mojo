# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def wrong(owner: List[Int], other: List[Int]) -> Optional[Optional[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def wrap(value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    var chain = kleisli[OptionalFamily](wrap)
    return pipeline(List[View]([Span(owner)])).find_map_effect(chain).get()

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
