# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(var a: Int, var b: Int) -> Tuple[Int,Int,Int]: return (a,b,a)
def main(): _ = map_accumulate(step,0,[1])
