"""Compiler-crash probe: Mojo 1.2.0 (2016d0cd) segfaults while compiling this file.

A struct stores a function type whose result contains that struct
(Call -> def(...) -> Node -> Call). The IO engine avoids the shape by having
callbacks write their node into a lent slot. A crash is never a valid rejection;
rerun this probe on each proposed toolchain.
"""
struct Call[E: Movable & Deinitable](Movable):
    var invoke: def(Int) thin -> Node[Self.E]
    def __init__(out self, invoke: def(Int) thin -> Node[Self.E]):
        self.invoke = invoke

struct Node[E: Movable & Deinitable](Movable):
    var call: Optional[Call[Self.E]]
    var tag: Int
    def __init__(out self, tag: Int):
        self.call = None
        self.tag = tag

def make(tag: Int) -> Node[Int]:
    return Node[Int](tag)

def main():
    var node = Node[Int](1)
    node.call = Optional(Call[Int](make))
    print("function-typed recursion ok", node.call.take().invoke(5).tag)
