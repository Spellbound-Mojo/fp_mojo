from fp.functions import pipeline
from fp.callables import Unary, MutableUnary
from std.testing import assert_equal

def present(var value: Int) -> Optional[Int]: return Optional(value + 1)
def never(var value: Int) raises Never -> Optional[Int]: return Optional(value + 2)
def checked(var value: Int) raises Int -> Optional[Int]:
    if value < 0: raise value
    return Optional(value)
def text(var value: String) -> Optional[String]: return Optional(value^)

@fieldwise_init
struct InferredShared(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Self.Out: return Optional(value + 3)

@fieldwise_init
struct InferredMutable(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls += 1
        return Optional(value + self.calls)

@fieldwise_init
struct InferredRaising(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out: raise value

def forward[T: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, //, F: def(var T) raises X -> Optional[T]](
    var values: List[T], ref[o] callback: F
) raises X -> Optional[List[T]]:
    return pipeline(values^).raising[X]().traverse(callback).get()

def pure() -> Optional[List[Int]]:
    var callback: def(var Int) raises Never thin -> Optional[Int] = never
    return pipeline(List[Int]([1])).raising[String]().traverse(callback).get()

def main() raises:
    assert_equal(pure().value(), [3])
    var pointer: def(var Int) thin -> Optional[Int] = present
    assert_equal(pipeline(List[Int]([1])).traverse(pointer).get_or(List[Int]()), [2])
    var strings: def(var String) thin -> Optional[String] = text
    assert_equal(pipeline(List[String](["one"])).traverse(strings).get_or(List[String]()), ["one"])
    assert_equal(pipeline(List[Int]([1, 2])).traverse(InferredShared()).get_or(List[Int]()), [4, 5])
    assert_equal(pipeline(List[Int]([1, 2])).traverse(InferredMutable(0)).get_or(List[Int]()), [2, 4])
    var error = 0
    var checked_pointer: def(var Int) raises Int thin -> Optional[Int] = checked
    try: _ = pipeline(List[Int]([1, -2, 3])).raising[Int]().traverse(checked_pointer).get()
    except value: error = value
    assert_equal(error, -2)
    try: _ = pipeline(List[Int]([8])).traverse(InferredRaising()).get()
    except value: error = value
    assert_equal(error, 8)
    var calls = 0
    def captured(var value: Int) raises Int {mut calls} -> Optional[Int]:
        calls += 1
        return checked(value)
    try: _ = forward(List[Int]([1, -3, 4]), captured)
    except value: error = value
    assert_equal(error, -3)
    assert_equal(calls, 2)
    try: _ = captured(5)
    except _: raise Error("unexpected error")
    assert_equal(calls, 3)
