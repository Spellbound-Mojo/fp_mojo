# error: no matching function in call to 'run'
from fp.algebra import traverse, ListFamily, pure
from fp.effects import State, run
from fp.callables import OnceUnary

@fieldwise_init
struct Once(OnceUnary,Defaultable):
    comptime Arg=Int
    comptime Out=type_of(pure[State[Int]](Int()))
    def call_once(deinit self,var item:Int)->Self.Out:
        return pure[State[Int]](item)

def main() raises:
    var values:List[Int]=[1,2]
    _=run[State[Int]](traverse[State[Int], ListFamily](values^,Once()),0)
