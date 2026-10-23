# error: no matching method
from fp.functions import piped
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main():
    var xs:List[Int]=[2]
    _=piped(Optional(1)).map_n((xs^,Optional(3)),add)
