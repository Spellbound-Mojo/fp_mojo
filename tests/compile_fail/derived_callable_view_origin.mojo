# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Ok

def wrong(owner: List[Int], other: List[Int]) -> Result[List[Span[Int, origin_of(other)]], String]:
    comptime View = type_of(Span(owner))
    def wrap(value: View) -> Result[Optional[View], String]: return Ok(Optional(value))
    var chain = kleisli[ResultFamily[String]](wrap)
    return pipeline(List[View]([Span(owner)])).traverse_filter(chain).get()

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
