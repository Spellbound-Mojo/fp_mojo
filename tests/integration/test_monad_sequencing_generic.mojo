"""Imported native forwarding preserves borrowed origins and raised errors."""
from fp.functions import piped
from fp.iteration import iterated
from fp.data import Result, Ok
from fp.algebra import ResultFamily, OptionalFamily
from std.testing import assert_equal


def msg_optional[P: Movable & Deinitable,R: Movable & Deinitable,X: Movable & Deinitable,
                 C: def(P) raises X -> R](var value: Optional[P],ref function: C
) raises X -> Optional[P]:
    return piped(value^).flat_tap[P=P,R=R,X=X](function).get()


def msg_result[P: Movable & Deinitable,R: Movable & Deinitable,E: Movable & Deinitable,X: Movable & Deinitable,
               C: def(P) raises X -> R](var value: Result[P,E],ref function: C
) raises X -> Result[P,E] where R == Result[ResultFamily[E].Element[R],E]:
    return piped(value^).flat_tap[P=P,R=R,X=X](function).get()


def msg_pair[P: Movable & Deinitable,R: Movable & Deinitable,X: Movable & Deinitable,
             C: def(P) raises X -> R](var value: Optional[P],ref function: C
) raises X -> Optional[Tuple[P,OptionalFamily.Element[R]]]:
    return piped(value^).flat_pair_with[P=P,R=R,X=X](function).get()


def msg_result_pair[P: Movable & Deinitable,R: Movable & Deinitable,E: Movable & Deinitable,X: Movable & Deinitable,
                    C: def(P) raises X -> R](var value: Result[P,E],ref function: C
) raises X -> Result[Tuple[P,ResultFamily[E].Element[R]],E] where R == Result[ResultFamily[E].Element[R],E]:
    return piped(value^).flat_pair_with[P=P,R=R,X=X](function).get()


def msg_before[T: Movable & Deinitable,R: Movable & Deinitable,X: Movable & Deinitable,
               C: def() raises X -> R](var value: List[T],ref function: C
) raises X -> List[T] where conforms_to(T,Copyable):
    return piped(value^).before[R=R,X=X](function).get()


def msg_after[T: Movable & Deinitable,R: Movable & Deinitable,X: Movable & Deinitable,
              C: def() raises X -> R](var value: List[T],ref function: C
) raises X -> R:
    return piped(value^).followed_by[R=R,X=X](function).get()


def msg_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    def observe(value: V) raises String -> Optional[Int]: return Optional(value[0])
    def result(value: V) raises String -> Result[Int,String]: return Ok(value[0])
    def branches() raises String -> List[Int]: return List[Int]([1,2])
    var retained = msg_optional(Optional(view),observe)
    comptime assert type_of(retained) == Optional[V]
    assert_equal(retained.value()[1],8)
    assert_equal(msg_result(Result[V,String](Ok(view)),result)._ok().value[1],8)
    def projection(value: V) raises String -> Optional[V]: return Optional(value)
    var paired = msg_pair(Optional(view),projection)
    comptime assert type_of(paired) == Optional[Tuple[V,V]]
    assert_equal(paired.value()[0][0],7)
    assert_equal(paired.value()[1][1],8)
    def result_projection(value: V) raises String -> Result[V,V]: return Ok(value)
    var result_pair = msg_result_pair(Result[V,V](Ok(view)),result_projection)
    comptime assert type_of(result_pair) == Result[Tuple[V,V],V]
    assert_equal(result_pair._ok().value[1][1],8)
    var copied = msg_before(List[V]([view]),branches)
    assert_equal(copied[1][0],7)
    assert_equal(msg_after(List[V]([view]),branches),[1,2])
    def lazy(value: V) -> List[Int]: return List[Int]([value[0]])
    var lazy_retained = iterated(List[V]([view])).flat_tap(lazy).to_list()
    comptime assert type_of(lazy_retained) == List[V]
    assert_equal(lazy_retained[0][1],8)
    def lazy_projection(value: V) -> List[V]: return List[V]([value])
    var lazy_pairs = iterated(List[V]([view])).flat_pair_with(lazy_projection).to_list()
    comptime assert type_of(lazy_pairs) == List[Tuple[V,V]]
    assert_equal(lazy_pairs[0][1][1],8)
    def failed(value: V) raises V -> Optional[Int]: raise value
    var code = 0
    try:
        _ = msg_optional(Optional(view),failed)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code,8)
    code = 0
    try:
        _ = msg_pair(Optional(view),failed)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code,8)


def main() raises:
    msg_origins([7,8])
    print('monad sequencing generic: ok')
