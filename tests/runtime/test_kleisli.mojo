"""Kleisli reuses native family semantics and preserves callback receivers."""
from fp.functions import kleisli, pipeline, pipeline_values
from fp.iteration import iterated, map as iterator_map, flat_map as iterator_flat_map, traverse as iterator_traverse
from fp.algebra import flat_map, traverse
from std.collections import Array, Deque, LinkedList, Dict, StringDict
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, IdentityFamily, ArrayFamily, DequeFamily, LinkedListFamily, map
from fp.data import Result, Ok, Err
from fp.callables import Unary, MutableUnary, OnceUnary, call_once
from fp.effects import Reader, State, run
from algebra_support.box import Box, BoxMonad
from algebra_support.external import PublicMonad
from std.testing import assert_equal, assert_true, assert_false


def k_start(x: Int) -> Result[Int, String]: return Ok(x + 1)
def k_next(x: Int) -> Result[Int, String]:
    if x < 0: return Err(String("negative"))
    return Ok(x * 2)
def k_text(x: Int) -> String: return String(x)
def k_length(x: String) -> Int: return x.byte_length()
def k_optional(x: Int) -> Optional[Int]:
    if x < 0: return Optional[Int]()
    return Optional(x + 1)
def k_list(x: Int) -> List[Int]: return [x, x + 10]
def k_twice(x: Int) -> Int: return x * 2

def k_families() raises:
    var chain = kleisli[ResultFamily[String]](k_start).then(k_next).map(k_text)
    assert_equal(chain.call(3).raise_on_err(), "8")
    assert_equal(chain.call_mut(4).raise_on_err(), "10")
    assert_true(chain.call(-3).is_err())
    assert_equal(call_once(chain^, 5).raise_on_err(), "12")
    var before = kleisli[ResultFamily[String]](k_next).compose(k_start).contramap(k_length)
    assert_equal(before.call(String("abc")).raise_on_err(), 8)
    var joined = kleisli[ResultFamily[String]](k_start).then(kleisli[ResultFamily[String]](k_next).map(k_text))
    assert_equal(joined.call(3).raise_on_err(), "8")
    var reversed = kleisli[ResultFamily[String]](k_next).compose(kleisli[ResultFamily[String]](k_start))
    assert_equal(reversed^.call_once(4).raise_on_err(), 10)
    var optional = kleisli[OptionalFamily](k_optional).then(k_optional).map(k_twice)
    assert_false(optional.call(-1))
    var some = optional.call(2)
    assert_equal(some.take(), 8)
    var many = kleisli[ListFamily](k_list).then(k_list).map(k_twice)
    assert_equal(many.call(1), [2, 22, 22, 42])
    assert_equal(many.call_mut(2), [4, 24, 24, 44])
    assert_equal(kleisli[IdentityFamily](k_twice).then(k_twice).call_once(2), 8)


@fieldwise_init
struct KMutable(MutableUnary):
    var count: Int
    comptime Arg = Int
    comptime Out = Result[Int, String]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        self.count += 1
        return Ok(arg + self.count)


def k_receiver_state() raises:
    var chain = kleisli[ResultFamily[String]](KMutable(0)).then(KMutable(10))
    assert_equal(chain.call_mut(1).raise_on_err(), 13)
    assert_equal(chain.call_mut(1).raise_on_err(), 15)
    assert_equal(chain^.call_once(1).raise_on_err(), 17)
    var calls = 0
    def observed(x: Int) {mut calls} -> Result[Int, String]:
        calls += 1
        return Ok(x)
    var skipped = kleisli[ResultFamily[String]](k_next).then(observed)
    assert_equal(calls, 0)
    assert_true(skipped.call(-1).is_err())
    assert_equal(calls, 0)
    assert_equal(skipped.call(2).raise_on_err(), 4)
    assert_equal(calls, 1)


def k_reader(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x + 1)
def k_state(x: Int) -> State[Int].Pure[Int]: return State[Int].pure(x + 1)

@fieldwise_init
struct KDeferredMutable(MutableUnary):
    var count: Int
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        self.count += 1
        return Reader[Int].pure(arg + self.count)


def k_deferred() raises:
    var calls = 0
    def inspect(x: Int) {mut calls} -> Int:
        calls += 1
        return x * 2
    var chain = kleisli[Reader[Int]](k_reader).then(k_reader).then(k_reader).map(inspect)
    var deferred = chain.call(1)
    assert_equal(calls, 0)
    assert_equal(run[Reader[Int]](deferred^, 100), 8)
    assert_equal(calls, 1)
    assert_equal(run[Reader[Int]](chain.call(2), 100), 10)
    assert_equal(run[Reader[Int]](chain^.call_once(3), 100), 12)
    assert_equal(calls, 3)
    var mutable = kleisli[Reader[Int]](k_reader).then(KDeferredMutable(0)).then(KDeferredMutable(10)).map(k_twice)
    var first = mutable.call_mut(1)
    assert_equal(run[Reader[Int]](first^, 0), 28)
    assert_equal(run[Reader[Int]](mutable.call_mut(1), 0), 32)
    assert_equal(run[Reader[Int]](mutable^.call_once(1), 0), 36)
    var stateful = kleisli[State[Int]](k_state).then(k_state).map(k_twice)
    assert_equal(run[State[Int]](stateful.call_mut(2), 7), (8, 7))


def k_box(x: Int) -> Box[Int]: return Box(x + 1)
def k_raise(x: Int) raises Int -> Result[Int, String]: raise x

def k_external_errors() raises:
    var external = kleisli[BoxMonad](k_box).then(k_box).map(k_twice)
    assert_equal(external.call(2).unwrap(), 8)
    var code = 0
    try:
        _ = kleisli[ResultFamily[String]](k_start).then(k_raise).call_once(9)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 10)
    var raising_chain = kleisli[ResultFamily[String]](k_start).then(k_raise)
    try:
        _ = pipeline(Optional(2)).map(raising_chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 3)
    try:
        _ = kleisli[PublicMonad[OptionalFamily, 2]](k_optional).then(k_optional).call_once(2)
    except error:
        code = error
    assert_equal(code, 703)
    try:
        _ = kleisli[PublicMonad[OptionalFamily, 1]](k_optional).map(k_twice).call_once(2)
    except error:
        code = error
    assert_equal(code, 702)


def k_callback_admission() raises:
    var chain = kleisli[ResultFamily[String]](k_start).then(k_next)
    var eager = pipeline(List[Int]([1, 2])).map(chain).get()
    assert_equal(eager[0].copy().raise_on_err(), 4)
    assert_equal(eager[1].copy().raise_on_err(), 6)
    var lazy = iterated(List[Int]([3, 4])).map(chain).collect_list()
    assert_equal(lazy[0].copy().raise_on_err(), 8)
    assert_equal(lazy[1].copy().raise_on_err(), 10)
    var direct = Result[Int, String](Ok(5)).map(chain)
    assert_equal(direct^.raise_on_err().raise_on_err(), 12)
    assert_equal(Result[Int, String](Ok(5)).flat_map(chain).raise_on_err(), 12)
    assert_equal(pipeline(Result[Int, String](Ok(5))).flat_map(chain).get().raise_on_err(), 12)
    assert_equal(flat_map[ResultFamily[String]](Result[Int, String](Ok(5)), chain).raise_on_err(), 12)
    var gathered = pipeline(List[Int]([1, 2])).traverse[ResultFamily[String]](chain).get()
    assert_equal(gathered^.raise_on_err(), [4, 6])
    assert_equal(traverse[ResultFamily[String], ListFamily](List[Int]([2, 3]), chain).raise_on_err(), [6, 8])
    assert_equal(iterated(range(2)).traverse[ResultFamily[String]](chain).raise_on_err(), [2, 4])
    assert_equal(iterator_traverse[ResultFamily[String]](range(2), chain).raise_on_err(), [2, 4])
    var mapped = map[OptionalFamily](Optional(6), chain)
    assert_equal(mapped.take().raise_on_err(), 14)
    var explicit = pipeline[OptionalFamily](Optional(6)).map(chain).get()
    assert_equal(explicit.take().raise_on_err(), 14)
    var free = iterator_map(List[Int]([7]), chain)
    var free_item = free.__next__()
    assert_equal(free_item^.raise_on_err(), 16)
    var branching = kleisli[ListFamily](k_list).then(k_list)
    assert_equal(iterated(List[Int]([1, 2])).flat_map(branching).collect_list(), [1, 11, 11, 21, 2, 12, 12, 22])
    assert_equal(pipeline(List[Int]([1])).flat_map(branching).get(), [1, 11, 11, 21])
    var flat = iterator_flat_map(List[Int]([1]), branching)
    assert_equal(iterated(flat^).collect_list(), [1, 11, 11, 21])
    var deferred_chain = kleisli[Reader[Int]](k_reader).then(k_reader).map(k_twice)
    var actions = iterated(List[Int]([1, 2])).map(deferred_chain).collect_list()
    var second = actions.pop()
    var first = actions.pop()
    assert_equal(run[Reader[Int]](first^, 0), 6)
    assert_equal(run[Reader[Int]](second^, 0), 8)
    var outer = pipeline[Reader[Int]](Reader[Int].pure(3)).map(chain).get()
    assert_equal(run[Reader[Int]](outer^, 0).raise_on_err(), 8)
    # Reuse after every admission above: no callback was moved or copied.
    assert_equal(chain.call(7).raise_on_err(), 16)


def k_container_shapes() raises:
    var chain = kleisli[IdentityFamily](k_twice).map(k_text)
    var array: Array[Int, 2] = [1, 2]
    var mapped_array = pipeline[ArrayFamily[2]](array^).map(chain).get()
    comptime assert type_of(mapped_array) == Array[String, 2]
    assert_equal(mapped_array[1], "4")
    var deque = Deque[Int]()
    deque.append(3)
    var mapped_deque = pipeline[DequeFamily](deque^).map(chain).get()
    assert_equal(mapped_deque.pop(), "6")
    var linked = LinkedList[Int]()
    linked.append(4)
    assert_equal(iterated(pipeline[LinkedListFamily](linked^).map(chain).get()).collect_list(), ["8"])
    var dictionary = Dict[String, Int]()
    dictionary["a"] = 5
    assert_equal(pipeline_values(dictionary^).map(chain).get()["a"], "10")
    var strings = StringDict[Int]()
    strings["b"] = 6
    assert_equal(pipeline_values(strings^).map(chain).get()["b"], "12")
    var optional = pipeline(Optional(7)).map(chain).get()
    assert_equal(optional.take(), "14")
    assert_equal(pipeline(Result[Int, String](Ok(8))).map(chain).get().raise_on_err(), "16")
    var calls = 0
    def count(x: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(x)
    var observed = kleisli[OptionalFamily](count)
    var xs: List[Int] = [1, 2]
    var eager = pipeline(xs^).map(observed)
    assert_equal(calls, 2)
    _ = eager^.get()
    var ys: List[Int] = [3, 4]
    var lazy = iterated(ys^).map(observed)
    assert_equal(calls, 2)
    _ = lazy.__next__()
    assert_equal(calls, 3)
    _ = lazy^
    assert_equal(calls, 3)


def main() raises:
    k_families()
    k_receiver_state()
    k_deferred()
    k_external_errors()
    k_callback_admission()
    k_container_shapes()
