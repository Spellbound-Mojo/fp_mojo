"""Counted native cursor shared by traversal clients."""
from std.iter import Iterator

@fieldwise_init
struct Counted[origin:MutOrigin](Iterator):
    comptime Element=Int
    var pulls:Pointer[Int,origin=Self.origin]
    var index:Int
    var count:Int
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.index == self.count:
            raise StopIteration()
        self.index += 1
        return self.index

