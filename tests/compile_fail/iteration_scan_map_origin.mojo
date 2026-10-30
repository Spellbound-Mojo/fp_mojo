# error: origin_of(local)
from fp.iteration import scan_map
from std.iter import iter
def step(var carry:Int,var item:Int)->Tuple[Int,Int]: return (carry+item,item)
def check(anchor:List[Int]):
    var local:List[Int]=[1,2]
    var expected=scan_map(iter(anchor),0,step)
    var actual=scan_map(iter(local),0,step)
    expected=actual^
def main():
    var anchor:List[Int]=[1,2]
    check(anchor)
