# error: cannot implicitly convert
from fp.functions import pipeline

def wrong(mut owner: List[Int]) -> Optional[Tuple[Span[Int, origin_of(owner)], Int]]:
    var local: List[Int] = [1]
    return pipeline(Optional(Span(local))).tuple_right(7).get()

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
