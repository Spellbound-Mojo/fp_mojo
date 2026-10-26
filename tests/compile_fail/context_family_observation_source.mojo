# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I=ResultT[ListFamily,String]
def wrong(error:String)->Int:return 0
def main():
    _ = pipeline[I](List[Result[Int,Int]]([Result[Int,Int](Ok(1))])).tap_err(wrong).get()
