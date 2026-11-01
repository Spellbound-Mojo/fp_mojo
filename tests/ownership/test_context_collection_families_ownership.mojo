"""Explicit sequence families preserve move-only values, errors and origins."""
from fp.functions import pipeline
from fp.algebra import ArrayFamily, DequeFamily, LinkedListFamily
from std.collections import Array, Deque, LinkedList
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def checked(var token: Token) raises Token -> Token:
    if token.code < 0: raise token^
    return token^

def keep(token: Token) -> Bool: return token.code > 0
def same[T: Movable & Deinitable](var value: T) -> T: return value^

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var views: Array[View, 2] = [Span(owner), Span(owner)]
    var result = pipeline[ArrayFamily[2]](views^).map(same[View]).get()
    comptime assert type_of(result) == Array[View, 2]
    assert_equal(result[1].unsafe_ptr() == Span(owner).unsafe_ptr(), True)

def main() raises:
    var drops = ArcPointer(0)
    var values: Array[Token, 3] = [Token(1, drops), Token(-2, drops), Token(3, drops)]
    var code = 0
    try: _ = pipeline[ArrayFamily[3]](values^).raising[Token]().map(checked).get()
    except error:
        comptime assert type_of(error) == Token
        code = error.code
    assert_equal(code, -2)
    assert_equal(drops[], 3)
    var deque = Deque[Token]()
    deque.append(Token(4, drops))
    deque.append(Token(-5, drops))
    var selected = pipeline[DequeFamily](deque^).filter(keep).map(same[Token]).get()
    assert_equal(drops[], 4)
    _ = selected^
    assert_equal(drops[], 5)
    var linked = LinkedList[Token]()
    linked.append(Token(6, drops))
    var mapped = pipeline[LinkedListFamily](linked^).map(same[Token]).get()
    assert_equal(drops[], 5)
    _ = mapped^
    assert_equal(drops[], 6)
    origins(List[Int]([7, 8]))
