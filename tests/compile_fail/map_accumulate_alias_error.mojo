# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(var a:Int,var b:Int) raises Int -> Tuple[Int,Int]: return(a,b)
comptime Callback=def(var Int,var Int) raises Int thin -> Tuple[Int,Int]
def main():
    var callback:Callback=step
    _=map_accumulate[Y=Int,E=String](callback,0,[1])
