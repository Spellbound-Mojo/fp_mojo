# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(var a: Int) -> Tuple[Int,Int]: return (a,a)
def main(): _ = map_accumulate([1],0,step)
