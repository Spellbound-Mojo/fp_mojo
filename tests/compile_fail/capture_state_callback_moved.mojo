# error: uninitialized value
from fp.data import Capture, Result
from fp.callables import mut_ref, shared_ref
from fp.functions import pipeline
from fp.iteration import iterated

def step(mut state: Int, var value: Int) raises Int -> Int:
    state += value
    if value < 0: raise state
    return state

def main():
    var callback = Capture[Int]().stateful(step, 0)
    var pending = iterated(range(2)).map(callback^)
    _ = callback.run(1)
    _ = pending^.to_list()
