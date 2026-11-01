"""Typed iterator postprocessing infers targets and preserves effect semantics."""
from fp.iteration import iterated
from fp.callables import Unary, as_unary
from fp.data import Result, Err
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct Token(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct Select(Unary):
    comptime Arg = Token
    comptime Out = Optional[Optional[Token]]
    def call(self, var value: Token) -> Self.Out:
        if value.id % 2: return Optional(Optional[Token]())
        return Optional(Optional(value^))
@fieldwise_init
struct Expand(Unary):
    comptime Arg = Token
    comptime Out = Optional[List[Token]]
    def call(self, var value: Token) -> Self.Out:
        var values = List[Token]()
        values.append(value^)
        return Optional(values^)
def values(drops: ArcPointer[Int]) -> List[Token]:
    var output = List[Token]()
    for i in range(3): output.append(Token(i,drops))
    return output^
def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def keep(var value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    var selected = iterated(List[View]([view])).traverse_filter(as_unary(keep))
    comptime assert type_of(selected) == Optional[List[View]]
    assert_equal(Pointer(to=selected.value()[0][0]) == Pointer(to=owner[0]),True)
    def group(var value: View) -> Optional[List[View]]: return Optional(List[View]([value]))
    var flat = iterated(List[View]([view])).flat_traverse(as_unary(group))
    assert_equal(Pointer(to=flat.value()[0][0]) == Pointer(to=owner[0]),True)
    def fail(var value: View) {error} -> Result[Optional[View],Failure]: return Err(error)
    var failed = iterated(List[View]([view])).traverse_filter(as_unary(fail))
    var stored = failed^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var selected = iterated(values(drops)).traverse_filter(Select())
    assert_equal(len(selected.value()),2)
    assert_equal(drops[],1)
    _ = selected^
    assert_equal(drops[],3)
    var expanded = iterated(values(drops)).flat_traverse(Expand())
    assert_equal(len(expanded.value()),3)
    assert_equal(drops[],3)
    _ = expanded^
    assert_equal(drops[],6)
    origins([3],[7])
    def reject(var value: Token) -> Optional[Optional[Token]]:
        if value.id == 1: return None
        return Optional(Optional(value^))
    assert_equal(Bool(iterated(values(drops)).traverse_filter(as_unary(reject))),False)
    assert_equal(drops[],9)
    def reject_flat(var value: Token) -> Optional[List[Token]]:
        if value.id == 1: return None
        var out = List[Token]()
        out.append(value^)
        return Optional(out^)
    assert_equal(Bool(iterated(values(drops)).flat_traverse(as_unary(reject_flat))),False)
    assert_equal(drops[],12)
