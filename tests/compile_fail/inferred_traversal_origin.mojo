# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def keep(var view: View) -> Optional[View]: return Optional(view)
    return pipeline(List[View]([Span(owner)])).traverse(keep).get()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
