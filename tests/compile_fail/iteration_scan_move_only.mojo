# error: does not conform to trait 'Copyable & Deinitable'
from fp.iteration import scan_left
from std.iter import iter

@fieldwise_init
struct State(Movable):
    var value: Int

def step(var state: State, var value: Int) -> State:
    state.value += value
    return state^

def main():
    _ = scan_left(step, State(0), iter(range(2)))
