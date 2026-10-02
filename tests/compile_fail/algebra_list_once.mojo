# error: List callbacks must be repeatable
from fp.algebra import map, ListFamily
from fp.callables import OnceUnary

@fieldwise_init
struct Once(OnceUnary):
    var value:Int
    comptime Arg=Int
    comptime Out=Int
    def call_once(deinit self,var item:Int)->Int:
        return self.value

def main():
    var values:List[Int]=[1,2]
    _=map[ListFamily](Once(3),values^)
