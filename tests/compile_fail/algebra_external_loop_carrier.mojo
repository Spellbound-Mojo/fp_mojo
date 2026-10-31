# error: no matching function in call to 'run'
from fp.algebra import pure, traverse, ListFamily
from fp.effects import Reader, StateT, run
from fp.callables import as_unary
from algebra_support.external import PublicMonad

comptime M=PublicMonad[Reader[Int]]
comptime I=StateT[M,Int]

def make(var value:Int)->type_of(pure[I](0)):
    return pure[I](value)

def main() raises:
    var values:List[Int]=[1,2]
    var computation=traverse[I, ListFamily](values^,as_unary(make))
    var delayed=run[I](computation^,0)
    var environment=0
    _=run[Reader[Int]](delayed^,environment)
