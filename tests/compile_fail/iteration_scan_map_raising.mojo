# error: no matching method in call to 'scan_map'
from fp.iteration import iterated
from std.iter import StopIteration
def step(var carry:Int,var item:Int) raises StopIteration ->Tuple[Int,Int]:
    raise StopIteration()
def main(): _=iterated(range(3)).scan_map(step,0)
