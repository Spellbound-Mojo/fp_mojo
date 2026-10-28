# error: invalid call to 'flatten'
from fp.data import Result,Ok,Err
def main():
    var left:List[Int]=[1]
    var right:List[Int]=[2]
    comptime Left=Span[Int,origin_of(left)]
    comptime Right=Span[Int,origin_of(right)]
    var inner=Result[Int,Right](Err(Span(right)))
    var outer=Result[Result[Int,Right],Left](Ok(inner^))
    _=outer^.flatten()
