# error: cannot implicitly convert
from fp.functions import pipeline
from fp.data import Result,Ok
def wrong[o:ImmOrigin](ref[o] owner:List[Int])->Result[Span[Int,o],Int]:
    var local:List[Int]=[1]
    return pipeline(Result[Int,Int](Ok(1))).fill(Span(local)).get()
def main():
    var owner:List[Int]=[2]
    _=wrong(owner)
