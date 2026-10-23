"""Move-only elements, mutable owned captures and exact terminal failure cleanup."""
from std.memory import ArcPointer
from std.iter import next, empty
from std.testing import assert_equal
from fp.iteration import iterated, count_where, for_each, collect_fold
from fp.algebra import Monoid, Semigroup, StringMonoid
from fp.callables import Binary, BorrowCallable, MutableUnary, MutableBinary


@fieldwise_init
struct I12OwnedToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I12OwnedFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def tokens(n: Int, drops: ArcPointer[Int]) -> List[I12OwnedToken]:
    var result = List[I12OwnedToken]()
    for i in range(n): result.append(I12OwnedToken(i,drops))
    return result^


def drop_prefix() raises:
    var drops = ArcPointer(0)
    var states = ArcPointer(0)
    var trace = ArcPointer(List[Int]())
    var state = I12OwnedToken(0, states)
    def predicate(value: I12OwnedToken) {var state^, trace} -> Bool:
        state.value += 1
        trace[].append(state.value)
        return value.value < 2
    var result = iterated(tokens(5,drops)).drop_while(predicate^)
    assert_equal(drops[],0)
    var first = next(result)
    assert_equal(first.value,2)
    assert_equal(trace[],[1,2,3])
    assert_equal(drops[],2)
    _ = first^
    _ = result^
    assert_equal(drops[],5)
    assert_equal(states[],1)
    assert_equal(trace[],[1,2,3])


def mapped() raises:
    var drops = ArcPointer(0)
    var states = ArcPointer(0)
    var outputs = ArcPointer(0)
    var state = I12OwnedToken(0, states)
    # Mojo 1.1 loses owned-capture writes for this native closure even when
    # called directly at O3. Mandatory native inlining avoids that lowering.
    @always_inline
    def combine(var a: I12OwnedToken, var b: I12OwnedToken) {var state^, outputs} -> I12OwnedToken:
        state.value += 1
        return I12OwnedToken(a.value + b.value + state.value, outputs)
    var result = iterated(tokens(4,drops)).zip_with(tokens(2,drops),combine^)
    assert_equal(drops[],0)
    var values = result^.to_list()
    assert_equal(len(values),2)
    assert_equal(values[0].value,1)
    assert_equal(values[1].value,4)
    assert_equal(drops[],6)
    assert_equal(states[],1)
    assert_equal(outputs[],0)
    _ = values^
    assert_equal(outputs[],2)
    var state2 = I12OwnedToken(0, states)
    @always_inline
    def indexed(var index: Int, var item: I12OwnedToken) {var state2^, outputs} -> I12OwnedToken:
        state2.value += 1
        return I12OwnedToken(index + item.value + state2.value, outputs)
    var indexed_result = iterated(tokens(3,drops)).map_with_index(indexed^)
    var first = next(indexed_result)
    assert_equal(first.value,1)
    var second = next(indexed_result)
    assert_equal(second.value,4)
    _ = first^
    _ = second^
    _ = indexed_result^
    assert_equal(states[],2)
    assert_equal(drops[],9)
    assert_equal(outputs[],4)


@fieldwise_init
struct I12OwnedEqual(Equatable, Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __eq__(self, other: Self) -> Bool: return self.value == other.value
    def __deinit__(deinit self): self.drops[] += 1


def terminals() raises:
    var drops = ArcPointer(0)
    var errors = ArcPointer(0)
    var trace = ArcPointer(List[Int]())
    def predicate(value: I12OwnedToken) raises I12OwnedFailure {trace,errors} -> Bool:
        trace[].append(value.value)
        if value.value == 2: raise I12OwnedFailure(22,errors)
        return True
    var caught = False
    try: _ = iterated(tokens(5,drops)).count_where(predicate)
    except e:
        assert_equal(e.code,22)
        caught = True
    assert_equal(caught,True)
    assert_equal(trace[],[0,1,2])
    assert_equal(drops[],5)
    assert_equal(errors[],1)
    trace[].clear()
    def observer(var value: I12OwnedToken) raises I12OwnedFailure {trace,errors} -> NoneType:
        trace[].append(value.value)
        if value.value == 1: raise I12OwnedFailure(33,errors)
        return None
    caught = False
    try: iterated(tokens(5,drops)).for_each(observer)
    except e:
        assert_equal(e.code,33)
        caught = True
    assert_equal(caught,True)
    assert_equal(trace[],[0,1])
    assert_equal(drops[],10)
    assert_equal(errors[],2)
    var first = iterated(tokens(3,drops)).first()
    assert_equal(drops[],12)
    assert_equal(first.value().value,0)
    _ = first^
    var last = iterated(tokens(3,drops)).last()
    assert_equal(last.value().value,2)
    assert_equal(drops[],15)
    _ = last^
    assert_equal(drops[],16)
    var nonempty = iterated(tokens(3,drops)).to_non_empty_list()
    assert_equal(nonempty.value().first().value,0)
    _ = nonempty^
    assert_equal(drops[],19)
    var needle = I12OwnedEqual(1,drops)
    var haystack = List[I12OwnedEqual]()
    for i in range(3):haystack.append(I12OwnedEqual(i,drops))
    assert_equal(iterated(haystack^).contains(needle),True)
    assert_equal(drops[],22)
    _ = needle^
    assert_equal(drops[],23)


struct I12TokenSemigroup(Semigroup):
    comptime Value = I12OwnedToken
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        left.value += right.value
        return left^


@fieldwise_init
struct I12Binary(Binary):
    comptime First = Int
    comptime Second = I12OwnedToken
    comptime Out = I12OwnedToken
    def call(self,var index: Int,var item: Self.Second) -> Self.Out:
        item.value += index
        return item^


@fieldwise_init
struct I12MutableBinary(MutableBinary):
    comptime First = Int
    comptime Second = I12OwnedToken
    comptime Out = I12OwnedToken
    var state: I12OwnedToken
    def call_mut(mut self,var index: Int,var item: Self.Second) -> Self.Out:
        self.state.value += 1
        item.value += index + self.state.value
        return item^


@fieldwise_init
struct I12Borrow(BorrowCallable):
    comptime Payload = I12OwnedToken
    comptime Result = Bool
    def invoke(self, ref payload: Self.Payload) capturing -> Bool:
        return payload.value < 2


@fieldwise_init
struct I12Sink(MutableUnary):
    comptime Arg = I12OwnedToken
    comptime Out = NoneType
    var trace: ArcPointer[List[Int]]
    def call_mut(mut self,var arg: Self.Arg) -> NoneType:
        self.trace[].append(arg.value)
        return None


def library_calls() raises:
    var drops = ArcPointer(0)
    var total = iterated(tokens(3,drops)).combine_all_optional[S=I12TokenSemigroup]()
    assert_equal(total.value().value,3)
    assert_equal(drops[],2)
    _ = total^
    assert_equal(drops[],3)
    var mapped = iterated(tokens(3,drops)).map_with_index(I12Binary()).to_list()
    assert_equal(mapped[2].value,4)
    _ = mapped^
    assert_equal(drops[],6)
    assert_equal(iterated(tokens(4,drops)).take_while(I12Borrow()).count(),2)
    assert_equal(iterated(tokens(4,drops)).drop_while(I12Borrow()).count(),2)
    assert_equal(count_where(I12Borrow(),tokens(4,drops)),2)
    var trace=ArcPointer(List[Int]())
    iterated(tokens(3,drops)).for_each(I12Sink(trace))
    assert_equal(trace[],[0,1,2])
    assert_equal(drops[],21)
    var paired = iterated(range(3)).zip_with(tokens(2,drops),I12Binary()).to_list()
    assert_equal(paired[1].value,2)
    _ = paired^
    assert_equal(drops[],23)
    var state_drops = ArcPointer(0)
    var stateful = iterated(tokens(2,drops)).map_with_index(I12MutableBinary(I12OwnedToken(0,state_drops))).to_list()
    assert_equal(stateful[0].value,1)
    assert_equal(stateful[1].value,4)
    assert_equal(state_drops[],1)
    _ = stateful^
    assert_equal(drops[],25)


@fieldwise_init
struct I12AggregateFailure(Movable):
    var code: Int


struct I12RaisingMonoid[fail_start: Bool](Monoid):
    comptime Value = String
    comptime Error = I12AggregateFailure
    @staticmethod
    def empty() raises Self.Error -> String:
        if Self.fail_start: raise I12AggregateFailure(10)
        return String()
    @staticmethod
    def combine(var left: String,var right: String) raises Self.Error -> String:
        if right == "2": raise I12AggregateFailure(20)
        return left + right


def aggregation_errors() raises:
    var calls = 0
    def select(var value: Int) {mut calls} -> Optional[String]:
        calls += 1
        return Optional(String(value))
    var caught = False
    try: _ = iterated(range(5)).collect_fold[M=I12RaisingMonoid[True]](select)
    except e:
        assert_equal(e.code,10)
        caught = True
    assert_equal(caught,True)
    assert_equal(calls,0)
    caught = False
    try: _ = iterated(range(5)).collect_fold[M=I12RaisingMonoid[False]](select)
    except e:
        assert_equal(e.code,20)
        caught = True
    assert_equal(caught,True)
    assert_equal(calls,3)
    calls = 0
    def fallible(var value: Int) raises I12AggregateFailure {mut calls} -> Optional[String]:
        calls += 1
        if value == 1: raise I12AggregateFailure(30)
        return Optional(String(value))
    caught = False
    try: _ = iterated(range(5)).collect_fold[M=I12RaisingMonoid[False]](fallible)
    except e:
        assert_equal(e.code,30)
        caught = True
    assert_equal(caught,True)
    assert_equal(calls,2)
    caught = False
    var strings: List[String] = ["0","1","2","3"]
    try: _ = iterated(strings^).combine_all_optional[S=I12RaisingMonoid[False]]()
    except e:
        assert_equal(e.code,20)
        caught = True
    assert_equal(caught,True)


def stop_predicate(value: Int) raises StopIteration -> Bool: raise StopIteration()
def stop_sink(var value: Int) raises StopIteration -> NoneType: raise StopIteration()
def stop_collect(var value: Int) raises StopIteration -> Optional[String]: raise StopIteration()


def main() raises:
    drop_prefix()
    mapped()
    terminals()
    library_calls()
    aggregation_errors()
    for mode in range(3):
        var caught=False
        try:
            if mode==0: _=count_where(stop_predicate,range(3))
            elif mode==1: for_each(stop_sink,range(3))
            else:
                _=collect_fold[M=StringMonoid](stop_collect,range(3))
        except StopIteration:caught=True
        assert_equal(caught,True)
