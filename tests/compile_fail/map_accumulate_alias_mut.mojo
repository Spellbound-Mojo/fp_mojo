# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(mut a:Int,var b:Int) -> Tuple[Int,Int]: return(a,b)
comptime Callback=def(mut Int,var Int) thin -> Tuple[Int,Int]
def main():
    var callback:Callback=step
    _=map_accumulate[Y=Int](callback,0,[1])
