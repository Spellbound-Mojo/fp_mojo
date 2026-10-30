"""Primitive operations compose across both State/Result orders."""
from fp.algebra import pure, map, flat_map, ResultFamily
from fp.effects import State, StateT, ResultT, run, lift, get, put, modify
from fp.callables import as_unary
from fp.data import Result, Ok, Err
from algebra_support import increment
from algebra_support.state_result import assert_output

comptime RS=ResultT[State[Int],Int]
comptime SR=StateT[ResultFamily[Int],Int]

def read_after_rs(var unused:NoneType)->type_of(lift[RS](get[State[Int]]())):
    return lift[RS](get[State[Int]]())

def read_after_sr(var unused:NoneType)->type_of(get[SR]()):
    return get[SR]()

def main() raises:
    assert_output[True](run[State[Int]](pure[RS](3),10),3,10)
    assert_output[False](run[SR](pure[SR](3),10),3,10)
    assert_output[True](run[State[Int]](map[RS](pure[RS](3),as_unary(increment)),10),4,10)
    assert_output[False](run[SR](map[SR](pure[SR](3),as_unary(increment)),10),4,10)
    assert_output[True](run[State[Int]](lift[RS](get[State[Int]]()),10),10,10)
    assert_output[False](run[SR](get[SR](),10),10,10)
    assert_output[True](run[State[Int]](flat_map[RS](lift[RS](put[State[Int]](20)),as_unary(read_after_rs)),10),20,20)
    assert_output[False](run[SR](flat_map[SR](put[SR](20),as_unary(read_after_sr)),10),20,20)
    assert_output[True](run[State[Int]](flat_map[RS](lift[RS](modify[State[Int]](as_unary(increment))),as_unary(read_after_rs)),10),11,11)
    assert_output[False](run[SR](flat_map[SR](modify[SR](as_unary(increment)),as_unary(read_after_sr)),10),11,11)
    assert_output[False](run[SR](lift[SR](Result[Int,Int](Ok(4))),10),4,10)
    assert_output[False](run[SR](map[SR](lift[SR](Result[Int,Int](Err(9))),as_unary(increment)),10),0,10,9)
    assert_output[True](run[State[Int]](map[RS](pure[State[Int]](Result[Int,Int](Err(9))),as_unary(increment)),10),0,10,9)
    print("State/Result: pure, map, lift, get, put, modify")
