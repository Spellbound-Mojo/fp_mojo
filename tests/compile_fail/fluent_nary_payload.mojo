# error: constraint
from fp.data import Result,Ok
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main(): _=Result[Int,String](Ok(1)).map_n((Result[String,String](Ok(String("x"))),Result[Int,String](Ok(3))),add)
