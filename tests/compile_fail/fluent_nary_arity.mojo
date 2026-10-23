# error: no matching method
from fp.functions import piped
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main(): _=piped(Optional(1)).map_n((Optional(2),),add)
