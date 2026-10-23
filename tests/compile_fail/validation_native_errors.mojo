# error: constraint
from fp.data import Result,Err
from fp.algebra import Semigroup
struct Merge(Semigroup):
    comptime Value=String
    comptime Error=String
    @staticmethod
    def combine(var left:String,var right:String) raises String -> String:
        raise left^
def add(a:Int,b:Int) raises Int -> Int:return a+b
def main() raises Int:
    _=Result[Int,String](Err(String('a'))).par_map_n[Merge]((Result[Int,String](Err(String('b'))),),add)
