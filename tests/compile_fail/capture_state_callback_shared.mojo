# error: no matching method in call to 'map'
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
    _ = pipeline(Optional(1)).map(shared_ref(callback)).get()
