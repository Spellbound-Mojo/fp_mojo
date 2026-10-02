# error: transformer: different inner family or error type
from fp.algebra import pure, map
from fp.effects import State, ResultT
from fp.callables import as_unary
from fp.data import Result, Err

def identity(var value:Int)->Int:
    return value

def main():
    # Equal-size error storage must not make distinct native types compatible.
    var wrong=pure[State[Int]](Result[Int,UInt64](Err(UInt64(7))))
    _=map[ResultT[State[Int],Int]](as_unary(identity),wrong^)
