# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def wrong(owner: List[Int], other: List[Int]) -> Result[Int, Span[Int, origin_of(other)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def error_view(var reason: String) {view} -> View: return view
    var handler = kleisli[IdentityFamily](error_view)
    return pipeline(Result[Int, String](Err(String("bad")))).map_err(handler).get()

def main():
    _ = wrong(List[Int]([1]), List[Int]([2]))
