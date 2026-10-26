# error: no matching function in call to 'flat_map'
from fp.algebra import pure, flat_map
from fp.effects import ResultT, State
from fp.callables import as_unary

comptime Expected=ResultT[State[Int],Int]
comptime Wrong=ResultT[State[Int],String]

def wrong(var value:Int)->type_of(pure[Wrong](Int())):
    return pure[Wrong](value)

def main():
    _=flat_map[Expected](as_unary(wrong),pure[Expected](1))
