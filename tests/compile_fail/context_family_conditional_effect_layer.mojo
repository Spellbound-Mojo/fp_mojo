# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I = ResultT[ListFamily,String]
def accept(error: String) -> Bool: return True
def wrong(var error: String) -> List[Result[Int,Int]]: return List[Result[Int,Int]]([Result[Int,Int](Ok(1))])
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).or_else_if(accept,wrong).get()
