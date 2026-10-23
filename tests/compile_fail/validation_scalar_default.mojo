# error: no matching
from fp.data import Result,Ok

def add(a:Int,b:Int)->Int:return a+b
def main():
    _=Result[Int,String](Ok(1)).par_map_n((Result[Int,String](Ok(2)),),add)
