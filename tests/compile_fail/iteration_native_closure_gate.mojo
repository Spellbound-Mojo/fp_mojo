# error: does not implement all requirements for 'Iterator'
"""Native feasibility rejection, not a conformance pass for capturing adapters.

The standard trait omits the capturing effect. This reproduces the restriction
without any fp import; pair with native thin and terminal closure controls.
"""
from std.iter import Iterator

@fieldwise_init
struct NativeAdapter[F: def(Int) -> Int](Iterator):
    comptime Element = Int
    var callback: Self.F
    def __next__(mut self) raises StopIteration -> Int:
        return self.callback(1)

def main():
    var offset = 2
    def callback(value: Int) {var offset} -> Int:
        return value + offset
    _ = NativeAdapter(callback)
