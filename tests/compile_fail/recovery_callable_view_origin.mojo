# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err

def wrong(owner: List[Int], other: List[Int]) -> Result[Int, Span[Int, origin_of(other)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def retry(var reason: String) {view} -> Result[Int, View]: return Err(view)
    var handler = kleisli[ResultFamily[View]](retry)
    return pipeline(Result[Int, String](Err(String("bad")))).or_else(handler).get()

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
