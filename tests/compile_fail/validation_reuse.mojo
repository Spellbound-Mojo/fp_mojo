# error: use of uninitialized
from fp.data import Result,Ok

def add(a:Int,b:Int)->Int:return a+b
def main():
    var value=Result[Int,List[String]](Ok(1))
    _=value^.par_map_n((Result[Int,List[String]](Ok(2)),),add)
    _=value.is_ok()
