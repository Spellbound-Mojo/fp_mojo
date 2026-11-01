# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I = ResultT[ListFamily,String]
def wrong(var error: String) -> List[Result[Int,Int]]: return List[Result[Int,Int]]([Result[Int,Int](Ok(0))])
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).or_else(wrong).get()
