# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def bad(var a:String,var b:Int)->Int: return b
def main(): _ = pipeline(Result[Int,List[String]](Ok(1))).par_map_n((Result[Int,List[String]](Ok(1)),),bad).get()
