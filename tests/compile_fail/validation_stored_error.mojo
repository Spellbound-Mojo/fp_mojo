from fp.functions import pipeline
# error: no matching method in call to 'par_map_n'
from fp.data import Result,Ok

def add(a:Int,b:Int)->Int:return a+b
def main():
    _=pipeline(Result[Int,List[String]](Ok(1))).par_map_n((Result[Int,List[Int]](Ok(2)),),add).get()
