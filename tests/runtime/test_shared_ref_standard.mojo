"""Shared references compose with partial application and lazy iteration."""
from fp.callables import shared_ref,call_once,invoke_borrowed_once
from fp.functions import partial,flow
from fp.data import Result,Ok
from fp.iteration import iterated
from std.testing import assert_equal

def add(left:Int,right:Int)->Int:return left+right
def twice(value:Int)->Int:return value*2
def positive(value:Int)->Bool:return value>0

def main() raises:
    var add_two=partial(add,2)
    var reference=shared_ref(add_two)
    assert_equal(call_once(reference,3),5)
    assert_equal(invoke_borrowed_once[Never](3,reference),5)
    assert_equal(iterated(range(3)).map(reference).to_list(),[2,3,4])
    var chain=flow(add_two^,twice)
    assert_equal(call_once(shared_ref(chain),3),10)
    var thunk=partial(add,2,3)
    assert_equal(call_once(shared_ref(thunk)),5)
    assert_equal(Result[Int,Int](Ok(1)).get_or_else(thunk),1)
    var predicate=partial(positive)
    assert_equal(iterated(range(-1,2)).filter(shared_ref(predicate)).to_list(),[1])
