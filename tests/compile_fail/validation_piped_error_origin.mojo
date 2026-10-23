# error: constraint
from fp.data import Result,Ok
from fp.functions import piped

def add(a:Int,b:Int)->Int:return a+b
def bad(left:List[Int],right:List[Int]):
    _=piped(Result[Int,List[Span[Int,origin_of(left)]]](Ok(1))).par_map_n((Result[Int,List[Span[Int,origin_of(right)]]](Ok(2)),),add)
def main():bad([1],[2])
