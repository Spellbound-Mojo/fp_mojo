# error: no matching method in call to 'scan_map'
from fp.iteration import iterated
def step(var carry:Int,var item:Int)->Tuple[String,Int]: return ("wrong",item)
def main(): _=iterated(range(3)).scan_map(step,0)
