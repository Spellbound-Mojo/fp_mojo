from fp.functions import pipeline
# error: no matching method in call to 'par_map_n'
from fp.data import Result,Ok

def bad(left:List[Int],right:List[Int]):
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    def keep(var value:R,b:Int)->R:return value
    _=pipeline(Result[L,List[String]](Ok(Span(left)))).par_map_n((Result[Int,List[String]](Ok(1)),),keep).get()
def main():bad([1],[2])
