# error: cannot implicitly convert
from fp.data import Result,Ok
def wrong[o:ImmOrigin](ref[o] owner:List[Int]) -> Result[Span[Int,o],Int]:
    var local:List[Int]=[1]
    comptime View=Span[Int,origin_of(local)]
    var nested=Result[Result[View,Int],Int](Ok(Result[View,Int](Ok(Span(local)))))
    return nested^.flatten()
def main():
    var owner:List[Int]=[2]
    _=wrong(owner)
