# error: action: native result differs from declared carrier
from fp.algebra import ResultFamily
from fp.effects import StateT, action, run
from fp.callables import as_unary
from fp.data import Result, Ok

def wrong(var state:Int)->Result[Tuple[Int,Int],UInt64]:
    return Result[Tuple[Int,Int],UInt64](Ok(Tuple(1,state)))

def main():
    comptime I=StateT[ResultFamily[Int],Int]
    _=run[I](action[I,Int](as_unary(wrong)),0)
