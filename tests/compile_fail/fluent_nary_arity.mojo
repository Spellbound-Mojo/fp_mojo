# error: no matching method in call to 'map_n'
from fp.functions import pipeline
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main(): _=pipeline(Optional(1)).map_n((Optional(2),),add)
