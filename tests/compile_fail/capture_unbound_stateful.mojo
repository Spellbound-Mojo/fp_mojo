# error: no matching function
# Construct the context before selecting a native state transition.
from fp.data import Capture

def step(mut state: Int, var value: Int) -> Int:
    state += value
    return state
def main():
    _ = Capture.stateful(step, 0)
