# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def add(var a:Int,var b:Int)->Int: return a+b
def main(): _ = pipeline(Result[Int,List[String]](Ok(1))).par_map_n((Result[Int,String](Ok(2)),),add).get()
