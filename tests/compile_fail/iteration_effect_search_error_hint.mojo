# error: constraint
from fp.iteration import find_map_effect
from fp.algebra import OptionalFamily
def wrong(var value:Int) raises String -> Optional[Optional[Int]]:raise String("failure")
def main():
    try: _=find_map_effect[OptionalFamily,E=String,X=Int](wrong,range(3))
    except:pass
