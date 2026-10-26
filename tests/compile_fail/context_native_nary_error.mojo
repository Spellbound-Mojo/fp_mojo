# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok
def wrong(var a: Int, var b: String, var c: Int) raises String -> Int: raise b^
def main():
    var pointer: def(var Int, var String, var Int) raises String thin -> Int = wrong
    _ = pipeline(Result[Int,List[String]](Ok(1))).raising[Int]().par_map_n((Result[String,List[String]](Ok(String("x"))), Result[Int,List[String]](Ok(2))), pointer).get()
