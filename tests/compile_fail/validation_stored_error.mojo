# error: constraint
from fp.data import Result,Ok

def add(a:Int,b:Int)->Int:return a+b
def main():
    _=Result[Int,List[String]](Ok(1)).par_map_n((Result[Int,List[Int]](Ok(2)),),add)
