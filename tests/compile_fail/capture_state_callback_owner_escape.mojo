# error: cannot implicitly convert
from fp.data import Capture, Result
from fp.callables import mut_ref, shared_ref
from fp.functions import pipeline
from fp.iteration import iterated

def step(mut state: Int, var value: Int) raises Int -> Int:
    state += value
    if value < 0: raise state
    return state

def wrong(mut original: List[Int]) -> Pointer[Int, origin_of(original)]:
    var callback = Capture[Int]().stateful(step, 0)
    _ = pipeline(Optional(1)).map(mut_ref(callback)).get()
    return Pointer(to=callback.state())
def main():
    var original: List[Int] = [1]
    _ = wrong(original)
