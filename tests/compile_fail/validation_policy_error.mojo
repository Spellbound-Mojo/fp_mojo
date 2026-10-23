# error: constraint
from fp.data import Result,Ok
from fp.algebra import StringMonoid

def add(a:Int,b:Int)->Int:return a+b
def main():
    _=Result[Int,List[String]](Ok(1)).par_map_n[StringMonoid]((Result[Int,List[String]](Ok(2)),),add)
