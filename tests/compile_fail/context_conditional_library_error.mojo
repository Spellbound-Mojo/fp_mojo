# error: no matching method
from fp.functions import pipeline
from fp.callables import Thunk
@fieldwise_init
struct Factory[E:Movable & Deinitable](Thunk):
    var failure:Self.E
    comptime Out=Optional[Int]
    comptime Error=Self.E
    def call(self) raises Self.Error -> Self.Out: return Optional(1)
def main(): _ = pipeline(Optional(True)).if_effect(Factory(1),Factory(String("bad"))).get()
