from fp.iteration import iterated
from fp.callables import Unary, MutableUnary
from fp.algebra import OptionalFamily
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
    return iterated(values^).traverse(callback)

def pure() -> Optional[List[Int]]:
    return iterated(List[Int]([1])).traverse(never)

def pure_void() -> Optional[NoneType]:
    return iterated(range(2)).traverse_void(never)

def main() raises:
    assert_equal(pure().value(), [3])
    assert_equal(Bool(pure_void()), True)
    assert_equal(iterated(List[Int]([1])).traverse(present).value(), [2])
    assert_equal(iterated(List[String](["one"])).traverse(text).value(), ["one"])
    assert_equal(iterated(List[Int]([1, 2])).traverse(InferredShared()).value(), [4, 5])
    assert_equal(iterated(List[Int]([1, 2])).traverse(InferredMutable(0)).value(), [2, 4])
    var error = 0
    try: _ = iterated(List[Int]([1, -2, 3])).traverse(checked)
    except value: error = value
    assert_equal(error, -2)
    try: _ = iterated(List[Int]([8])).traverse(InferredRaising())
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
    assert_equal(Bool(iterated(range(2)).traverse_void(never)), True)
    assert_equal(Bool(iterated(range(2)).traverse_void(InferredShared())), True)
    assert_equal(Bool(iterated(range(2)).traverse_void(InferredMutable(0))), True)
    try: _ = iterated(List[Int]([1, -4, 5])).traverse_void(captured)
    except value: error = value
    assert_equal(error, -4)
    assert_equal(calls, 5)
    try: _ = iterated(List[Int]([1, -5, 6])).traverse_void[OptionalFamily, Int, type_of(captured), Int](captured)
    except value: error = value
    assert_equal(error, -5)
    assert_equal(calls, 7)
    try: _ = iterated(List[Int]([1, -6, 7])).traverse[OptionalFamily, Int, type_of(captured)](captured)
    except value: error = value
    assert_equal(error, -6)
    assert_equal(calls, 9)
