# error: cannot implicitly convert
from algebra_support.fill_contracts import filled
from fp.algebra import ResultFamily
from fp.data import Result,Ok
def wrong[o:ImmOrigin](ref[o] owner:List[Int])->Result[Span[Int,o],Int]:
    var local:List[Int]=[1]
    return filled[ResultFamily[Int]](Result[Int,Int](Ok(1)),Span(local))
def main():
    var owner:List[Int]=[2]
    _=wrong(owner)
