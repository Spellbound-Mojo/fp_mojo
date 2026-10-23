from fp.functions import piped
# error: no matching method in call to 'map_n'
from fp.data import Result,Ok
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main(): _=piped(Result[Int,String](Ok(1))).map_n((Result[Int,Int](Ok(2)),Result[Int,String](Ok(3))),add).get()
