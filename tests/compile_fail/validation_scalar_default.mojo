from fp.functions import piped
# error: invalid call to 'par_map_n': lacking evidence
from fp.data import Result,Ok

def add(a:Int,b:Int)->Int:return a+b
def main():
    _=piped(Result[Int,String](Ok(1))).par_map_n((Result[Int,String](Ok(2)),),add).get()
