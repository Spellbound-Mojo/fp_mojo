# error: cannot implicitly convert
from fp.data import Capture, Result
from fp.callables import mut_ref, shared_ref
from fp.functions import pipeline
from fp.iteration import iterated

def step(mut state: Int, var value: Int) raises Int -> Int:
    state += value
    if value < 0: raise state
    return state

def view[T: Copyable & Deinitable](mut state: T, var fail: Bool) raises T -> T:
    if fail: raise state.copy()
    return state.copy()
def captured(values: List[Int]) -> Span[Int, origin_of(values)]:
    comptime V = Span[Int, origin_of(values)]
    var callback = Capture[V]().stateful(view[V], Span(values))
    var outputs = pipeline[Bool]([False]).map(callback^).get()
    return outputs.pop().get_or(Span(values))
def wrong(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var local: List[Int] = [1]
    return captured(local)
def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
