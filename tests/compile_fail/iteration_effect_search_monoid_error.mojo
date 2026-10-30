# error: constraint
from fp.iteration import fold_map_effect
from fp.algebra import OptionalFamily,Monoid
struct Bad(Monoid):
    comptime Value=String
    comptime Error=Int
    @staticmethod
    def empty() raises Int ->String:raise 1
    @staticmethod
    def combine(var a:String,var b:String) raises Int ->String:raise 2
def wrong(var value:Int) raises String ->Optional[String]:raise String("failure")
def main():
    try: _=fold_map_effect[OptionalFamily,Bad](range(3),wrong)
    except:pass
