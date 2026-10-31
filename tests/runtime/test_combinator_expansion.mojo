"""Shared combinators preserve timing, native carriers, errors and ownership."""
from std.collections import Array, Deque, LinkedList, StringDict
from std.hash import default_comp_time_hasher
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false, assert_true
from std.builtin.rebind import rebind_var
from fp.functions import pipeline, pipeline_values, Pipeline
from fp.iteration import iterated, collect_list
from fp.iteration import fill, compact, sum, sum_by, traverse, sequence, find_map
from fp.algebra import OptionalFamily, ListFamily, IdentityFamily, StringMonoid, Monoid, FunctorFilter, filter_map as family_filter_map
from fp.callables import BorrowCallable, MutableUnary, UnaryContract, as_unary
from fp.data import Result, Ok, Err
from test_container_map import ContainerMapItem, ContainerMapKey
from test_algebra_third_party import Cell, CellFamily
from test_filter_not import FilterNotRestarting


def expansion_square(x: Int) -> Int: return x * x
def expansion_key(x: Int) -> Int: return x % 3
def expansion_text(x: Int) -> String: return String(x)
def expansion_some(x: Int) -> Optional[Int]: return Optional(x * 2)
def expansion_select(x: Int) -> Optional[String]:
    if x > 1: return Optional(String(x))
    return None
def expansion_many(x: Int) -> List[Int]: return [x, x + 1]
def expansion_vector(x: Int) -> SIMD[DType.float32, 2]: return SIMD[DType.float32, 2](Float32(x))
def expansion_item_key(x: ContainerMapItem) -> Int: return x.value


@fieldwise_init
struct ExpansionFailure(Movable):
    var code: Int


struct ExpansionMonoid(Monoid):
    comptime Value = Int
    comptime Error = ExpansionFailure
    @staticmethod
    def empty() raises Self.Error -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Self.Error -> Int:
        if right == 2: raise ExpansionFailure(2)
        return left + right

@fieldwise_init
struct ExpansionInspect(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    var calls: ArcPointer[Int]
    def invoke(self, ref payload: Int) capturing -> Int:
        self.calls[] += 1
        return payload * 3

@fieldwise_init
struct ExpansionSelect(MutableUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    var calls: Int
    def call_mut(mut self, var arg: Int) -> Optional[Int]:
        self.calls += 1
        if arg > 0: return Optional(arg + self.calls)
        return None


@fieldwise_init
struct ExpansionDeferredSelect[F: UnaryContract & Movable & Deinitable](Movable):
    var function: Self.F
    var source: List[Self.F.Arg]
    def run(deinit self) raises Self.F.Error -> ListFamily.MapFiltered[List[Self.F.Arg], Self.F]:
        return ListFamily.filter_map(self.function^, self.source^)


struct ExpansionDeferredFamily(FunctorFilter):
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = List[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ExpansionDeferredSelect[F]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises F.Error -> List[F.Out]:
        return ListFamily.map(f^, value^)
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> ExpansionDeferredSelect[F]:
        comptime assert V == List[F.Arg]
        return ExpansionDeferredSelect(f^, rebind_var[List[F.Arg]](value^))


def expansion_transforms() raises:
    var xs: List[Int] = [1, 2, 3]
    assert_equal(pipeline(xs.copy()).fill(4).replace(4, 7).get(), [7, 7, 7])
    assert_equal(pipeline(xs.copy()).replace(2, 9).get(), [1, 9, 3])
    assert_equal(iterated(xs.copy()).replace(2, 9).to_list(), [1, 9, 3])
    assert_equal(collect_list(fill(7, range(3))), [7, 7, 7])
    assert_equal(pipeline(xs.copy()).tuple_left('x').get()[1], ('x', 2))
    assert_equal(iterated(xs.copy()).tuple_right('x').to_list()[1], (2, 'x'))
    assert_equal(pipeline(xs.copy()).pair_with(expansion_square).get()[2], (3, 9))
    assert_equal(iterated(xs.copy()).pair_with(expansion_square).to_list()[2], (3, 9))
    assert_equal(len(pipeline(xs.copy()).void().get()), 3)
    assert_equal(len(iterated(xs.copy()).void().to_list()), 3)
    assert_true(pipeline(Optional(2)).void().get())
    assert_false(pipeline(Optional[Int]()).void().get())
    assert_equal(pipeline[ListFamily](xs^).fill(7).get(), [7, 7, 7])
    assert_equal(pipeline[CellFamily](Cell(4)).fill(7).get().take(), 7)
    assert_equal(pipeline[IdentityFamily](5).fill(7).get(), 7)
    var calls = ArcPointer(0)
    assert_equal(pipeline(4).tap(ExpansionInspect(calls)).get(), 4)
    assert_equal(pipeline(List[Int]([1, 2])).tap_each(ExpansionInspect(calls)).get(), [1, 2])
    assert_equal(iterated(range(2)).pair_with(ExpansionInspect(calls)).to_list(), [(0, 0), (1, 3)])
    assert_equal(calls[], 5)
    var array: Array[Int, 2] = [1, 2]
    var mapped = pipeline(array^).elements().fill('a').get()
    comptime assert type_of(mapped) == Array[String, 2]
    assert_equal(mapped[0], 'a')
    var empty = Array[Int, 0](fill=0)
    assert_equal(len(pipeline(empty^).elements().fill('x').get()), 0)
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=2, shrink=False)
    deque.append(1)
    deque.append(2)
    var d = pipeline(deque^).fill(3).get()
    assert_equal(d._min_capacity, 4)
    assert_false(d._shrink)
    d.append(4)
    assert_equal(collect_list(d^), [3, 4])
    var linked = LinkedList[Int]()
    linked.append(4)
    assert_equal(collect_list(pipeline(linked^).tuple_right(2).get()), [(4, 2)])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict['b'] = 2
    dict['a'] = 3
    var changed = pipeline_values(dict^).fill(4).get()
    comptime assert type_of(changed) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(changed['a'], 4)
    assert_equal(collect_list(changed^), ['b', 'a'])
    var kw = StringDict[Int]()
    kw['x'] = 1
    assert_equal(pipeline_values(kw^).fill(2).get()['x'], 2)
    var bad = Result[Int, String](Err(String('bad')))
    assert_equal(pipeline(bad^).fill(3).get()._take_err(), 'bad')
    var good = Result[Int, String](Ok(4))
    assert_equal(pipeline(good^).pair_with(expansion_square).get()._take_ok(), (4, 16))


def expansion_selection() raises:
    var xs: List[Int] = [1, 2, 3]
    assert_equal(pipeline(xs.copy()).filter_map(expansion_select).get(), ['2', '3'])
    assert_equal(pipeline[ListFamily](xs.copy()).filter_map(expansion_select).get(), ['2', '3'])
    assert_equal(family_filter_map[ListFamily](xs.copy(), expansion_select), ['2', '3'])
    assert_equal(pipeline(xs.copy()).filter_map(ExpansionSelect(0)).get(), [2, 4, 6])
    assert_equal(pipeline(xs^).flat_map(expansion_many).get(), [1, 2, 2, 3, 3, 4])
    var opts: List[Optional[Int]] = [None, Optional(2), None, Optional(4)]
    assert_equal(pipeline(opts.copy()).compact().get(), [2, 4])
    assert_equal(iterated(opts.copy()).compact().to_list(), [2, 4])
    assert_equal(collect_list(compact(opts^)), [2, 4])
    var nested: List[List[Int]] = [[1, 2], [], [3]]
    assert_equal(pipeline(nested^).flatten().get(), [1, 2, 3])
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=2, shrink=False)
    deque.append(1)
    deque.append(2)
    var d = pipeline(deque^).filter_map(expansion_select).get()
    assert_equal(d._min_capacity, 4)
    assert_false(d._shrink)
    assert_equal(collect_list(d^), ['2'])
    var linked = LinkedList[Int]()
    linked.append(1)
    linked.append(2)
    assert_equal(collect_list(pipeline(linked^).filter_map(expansion_select).get()), ['2'])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict['b'] = 1
    dict['a'] = 3
    var selected = pipeline_values(dict^).filter_map(expansion_select).get()
    comptime assert type_of(selected) == Dict[String, String, default_comp_time_hasher]
    assert_equal(selected['a'], '3')
    assert_equal(collect_list(selected^), ['a'])
    var kw = StringDict[Int]()
    kw['x'] = 1
    kw['y'] = 2
    var ks = pipeline_values(kw^).filter_map(expansion_select).get()
    assert_equal(len(ks), 1)
    assert_equal(ks['y'], '2')
    assert_false(pipeline(Optional(1)).filter_map(expansion_select).get())
    assert_equal(pipeline(Optional(2)).filter_map(expansion_select).get().value(), '2')
    var deferred_calls = 0
    def expansion_deferred(x: Int) {mut deferred_calls} -> Optional[Int]:
        deferred_calls += 1
        return Optional(x * 2)
    var deferred = pipeline[ExpansionDeferredFamily](List[Int]([1, 2])).filter_map(expansion_deferred).get()
    assert_equal(deferred_calls, 0)
    assert_equal(deferred^.run(), [2, 4])
    assert_equal(deferred_calls, 2)
    var nested_options: List[Optional[Int]] = [None, Optional(3)]
    var deferred_compact = pipeline[ExpansionDeferredFamily](nested_options^).compact().get()
    assert_equal(deferred_compact^.run(), [3])


def expansion_timing() raises:
    var calls = 0
    def expansion_observe(x: Int) {mut calls}:
        calls += x
    var eager = pipeline(List[Int]([1, 2])).tap_each(expansion_observe)
    assert_equal(calls, 3)
    assert_equal(eager^.get(), [1, 2])
    var lazy = iterated(range(1, 4)).tap_each(expansion_observe)
    assert_equal(calls, 3)
    assert_equal(next(lazy), 1)
    assert_equal(calls, 4)
    _ = lazy^
    assert_equal(calls, 4)
    var drops = ArcPointer(0)
    var state = ContainerMapItem(0, drops)
    def expansion_owned(x: Int) {var state^} -> Int:
        state.value += 1
        return x + state.value
    assert_equal(iterated(range(3)).pair_with(expansion_owned^).to_list(), [(0, 1), (1, 3), (2, 5)])
    assert_equal(drops[], 1)
    var pulls = ArcPointer(0)
    var fused = iterated(FilterNotRestarting(pulls)).fill(8)
    assert_equal(next(fused), 8)
    for _ in range(2):
        var stopped = False
        try: _ = next(fused)
        except: stopped = True
        assert_true(stopped)
    assert_equal(pulls[], 2)
    var position = iter(range(5))
    assert_equal(next(position), 0)
    assert_equal(iterated(position).sum(), 10)
    var scans = 0
    def expansion_first(x: Int) {mut scans} -> Optional[Int]:
        scans += 1
        if x == 2: return Optional(x * 10)
        return None
    assert_equal(iterated(range(10)).find_map(expansion_first).value(), 20)
    assert_equal(scans, 3)
    assert_equal(find_map(range(4), expansion_first).value(), 20)
    assert_equal(scans, 6)


def expansion_reductions() raises:
    var xs: List[Int] = [1, 2, 3, 4]
    assert_equal(pipeline(xs.copy()).sum().get(), 10)
    assert_equal(pipeline(xs.copy()).sum_by(expansion_square).get(), 30)
    assert_equal(iterated(xs.copy()).sum_by(expansion_square), 30)
    assert_equal(sum(xs.copy()), 10)
    assert_equal(sum_by(xs.copy(), expansion_square), 30)
    assert_equal(pipeline(xs.copy()).fold_map[StringMonoid](expansion_text).get(), '1234')
    assert_equal(iterated(xs.copy()).fold_map[StringMonoid](expansion_text), '1234')
    assert_equal(iterated(xs.copy()).min_by(expansion_key).value(), 3)
    assert_equal(pipeline(xs.copy()).max_by(expansion_key).get().value(), 2)
    assert_equal(pipeline(xs.copy()).find_map(expansion_select).get().value(), '2')
    assert_equal(pipeline(xs.copy()).sum_by(expansion_vector).get(), SIMD[DType.float32, 2](10))
    assert_equal(iterated(xs^).sum_by(expansion_vector), SIMD[DType.float32, 2](10))
    assert_equal(pipeline(List[Int]()).sum().get(), 0)
    assert_false(iterated(List[Int]()).min_by(expansion_key))
    assert_false(iterated(List[Int]()).find_map(expansion_some))
    var texts: List[String] = ['a', 'bc']
    assert_equal(pipeline(texts.copy()).combine_all[StringMonoid]().get(), 'abc')
    assert_equal(iterated(texts^).combine_all[StringMonoid](), 'abc')
    var floats: List[Float64] = [1.5, 2.5]
    assert_equal(pipeline(floats.copy()).sum().get(), 4.0)
    assert_equal(sum(floats^), 4.0)
    var vectors: List[SIMD[DType.float32, 2]] = [SIMD[DType.float32, 2](1, 2), SIMD[DType.float32, 2](3, 4)]
    assert_equal(iterated(vectors^).sum(), SIMD[DType.float32, 2](4, 6))
    var dict: Dict[String, Int] = {'a': 2, 'b': 3}
    assert_equal(pipeline_values(dict^).sum().get(), 5)
    var kw = StringDict[Int]()
    kw['a'] = 4
    assert_equal(pipeline_values(kw^).sum_by(expansion_square).get(), 16)
    var array: Array[Int, 2] = [2, 3]
    assert_equal(pipeline(array^).elements().sum().get(), 5)


def expansion_effects() raises:
    var xs: List[Int] = [1, 2, 3]
    assert_equal(pipeline(xs.copy()).traverse[OptionalFamily](expansion_some).get().value(), [2, 4, 6])
    assert_equal(iterated(xs.copy()).traverse[OptionalFamily](expansion_some).value(), [2, 4, 6])
    assert_equal(traverse[OptionalFamily](xs^, expansion_some).value(), [2, 4, 6])
    var os: List[Optional[Int]] = [Optional(4), Optional(6)]
    assert_equal(iterated(os.copy()).sequence[OptionalFamily]().value(), [4, 6])
    assert_equal(sequence[OptionalFamily](os^).value(), [4, 6])
    var failed: List[Optional[Int]] = [Optional(4), None]
    assert_false(pipeline(failed^).sequence[OptionalFamily]().get())
    var calls = 0
    def expansion_stop(x: Int) {mut calls} -> Optional[Int]:
        calls += 1
        if x == 2: return None
        return Optional(x)
    assert_false(iterated(range(8)).traverse[OptionalFamily](expansion_stop))
    assert_equal(calls, 3)
    assert_equal(pipeline(Optional(2)).flat_map(expansion_some).get().value(), 4)
    assert_equal(pipeline(Optional(Optional(3))).flatten().get().value(), 3)
    var nested_result = Result[Result[Int, String], String](Ok(Result[Int, String](Ok(4))))
    assert_equal(pipeline(nested_result^).flatten().get()._take_ok(), 4)


def expansion_ownership() raises:
    var drops = ArcPointer(0)
    var xs: List[ContainerMapItem] = [ContainerMapItem(1, drops), ContainerMapItem(2, drops)]
    var pairs = pipeline(xs^).pair_with(expansion_item_key).get()
    assert_equal(drops[], 0)
    assert_equal(pairs[1][0].value, 2)
    _ = pairs^
    assert_equal(drops[], 2)
    var ys: List[ContainerMapItem] = [ContainerMapItem(3, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops)]
    var best = iterated(ys^).min_by(expansion_item_key)
    assert_equal(best.value().value, 1)
    assert_equal(drops[], 4)
    _ = best^
    assert_equal(drops[], 5)
    var keys = ArcPointer(0)
    var values = ArcPointer(0)
    var dict = Dict[ContainerMapKey, ContainerMapItem]()
    dict[ContainerMapKey(1, keys)] = ContainerMapItem(1, values)
    dict[ContainerMapKey(2, keys)] = ContainerMapItem(2, values)
    def expansion_keep_item(var x: ContainerMapItem) -> Optional[ContainerMapItem]:
        if x.value == 2: return Optional(x^)
        return None
    var kept = pipeline_values(dict^).filter_map(expansion_keep_item).get()
    assert_equal(keys[], 1)
    assert_equal(values[], 1)
    _ = kept^
    assert_equal(keys[], 2)
    assert_equal(values[], 2)
    var zs: Array[ContainerMapItem, 2] = [ContainerMapItem(1, drops), ContainerMapItem(2, drops)]
    assert_equal(pipeline(zs^).elements().min_by(expansion_item_key).get().value().value, 1)
    assert_equal(drops[], 7)


def expansion_errors() raises:
    var calls = 0
    def expansion_checked(x: Int) raises ExpansionFailure {mut calls} -> Optional[Int]:
        calls += 1
        if x == 2: raise ExpansionFailure(x)
        return Optional(x)
    var failed = False
    try: _ = pipeline(List[Int]([1, 2, 3])).raising[ExpansionFailure]().filter_map(expansion_checked).get()
    except error:
        comptime assert type_of(error) == ExpansionFailure
        assert_equal(error.code, 2)
        failed = True
    assert_true(failed)
    failed = False
    try: _ = pipeline(List[Int]([1, 2, 3])).combine_all[ExpansionMonoid]().get()
    except error:
        comptime assert type_of(error) == ExpansionFailure
        assert_equal(error.code, 2)
        failed = True
    assert_true(failed)
    assert_equal(calls, 2)
    def expansion_bad_key(x: Int) raises ExpansionFailure -> Int:
        if x == 2: raise ExpansionFailure(2)
        return x
    failed = False
    try: _ = iterated(range(4)).max_by(expansion_bad_key)
    except error:
        comptime assert type_of(error) == ExpansionFailure
        failed = True
    assert_true(failed)
    failed = False
    try: _ = pipeline(List[Int]([1, 2])).sum_by(expansion_bad_key).get()
    except error:
        comptime assert type_of(error) == ExpansionFailure
        failed = True
    assert_true(failed)
    def expansion_stop_error(x: Int) raises StopIteration -> Optional[Int]:
        raise StopIteration()
    failed = False
    try: _ = iterated(range(2)).find_map(expansion_stop_error)
    except: failed = True
    assert_true(failed)


def expansion_origins(anchor: List[Int]) raises:
    def expansion_view(x: Int) {anchor} -> Span[Int, origin_of(anchor)]:
        return Span(anchor)
    var pairs = pipeline(List[Int]([1, 2])).pair_with(expansion_view).get()
    assert_equal(pairs[0][1][1], 12)
    var lazy = iterated(range(2)).pair_with(expansion_view)
    assert_equal(next(lazy)[1][0], 11)
    var spans: List[Span[Int, origin_of(anchor)]] = [Span(anchor)]
    def expansion_view_key(x: Span[Int, origin_of(anchor)]) {anchor} -> Int: return len(x)
    assert_equal(pipeline(spans^).min_by(expansion_view_key).get().value()[1], 12)


def main() raises:
    expansion_transforms()
    expansion_selection()
    expansion_timing()
    expansion_reductions()
    expansion_effects()
    expansion_ownership()
    expansion_errors()
    expansion_origins([11, 12])
