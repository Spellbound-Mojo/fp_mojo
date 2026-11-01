# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline
def wrong(owner: List[Int], other: List[Int]) -> Optional[Optional[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def keep(value: View) -> Optional[Bool]: return Optional(True)
    return pipeline(List[View]([Span(owner)])).find_effect(keep).get()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
