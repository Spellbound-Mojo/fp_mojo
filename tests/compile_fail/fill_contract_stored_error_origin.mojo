# error: lacking evidence
from algebra_support.fill_contracts import filled
from fp.algebra import ResultFamily
from fp.data import Result,Ok
def wrong(left:List[Int],right:List[Int]):
    comptime Left=Span[Int,origin_of(left)]
    comptime Right=Span[Int,origin_of(right)]
    _=filled[ResultFamily[Left]](Result[Int,Right](Ok(1)),3)
def main():
    var left:List[Int]=[1]
    var right:List[Int]=[2]
    wrong(left,right)
