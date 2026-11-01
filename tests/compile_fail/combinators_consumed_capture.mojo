# error: use of uninitialized value 'callback'
from fp.functions import pipeline
from fp.callables import as_unary

@fieldwise_init
struct CombinatorOwnedState(Movable):
    var offset: Int

def main():
    var state = CombinatorOwnedState(2)
    def callback(var value: Int) {var state^} -> Int: return value + state.offset
    var mapped = pipeline(List[Int]([0, 1, 2])).map(as_unary(callback^)).get()
    print(callback(4))
    _ = mapped^
