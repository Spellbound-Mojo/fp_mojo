# error: cannot implicitly convert
from fp.data import Capture, Result
from fp.callables import mut_ref, shared_ref
from fp.functions import pipeline
from fp.iteration import iterated

def step(mut state: Int, var value: Int) raises Int -> Int:
    state += value
    if value < 0: raise state
    return state

def wrong() -> List[Result[Int, String]]:
    var callback = Capture[Int]().stateful(step, 0)
    return pipeline[Int]([-1]).map(callback^).get()
def main():
    _ = wrong()
