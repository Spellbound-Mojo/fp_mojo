"""Fluent applicative combination retains native family semantics."""
from fp.functions import pipeline
from fp.algebra import IdentityFamily, ListFamily, OptionalFamily
from fp.data import Result, Ok, Err
from fp.callables import MutableBinary, OnceBinary, Unary, MutableUnary, OnceUnary, as_unary
from fp.effects import Reader, State, get, run, modify
from test_algebra_third_party import Cell, CellFamily
from std.testing import assert_equal, assert_false
from std.memory import ArcPointer


def fc_add(a: Int, b: Int) -> Int: return a + b
def fc_text(a: Int, b: String) -> String: return String(a) + b


@fieldwise_init
struct FCFailure(Movable):
    var code: Int


def fc_raise(a: Int, b: Int) raises FCFailure -> Int:
    raise FCFailure(a + b)


@fieldwise_init
struct FCCombiner(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var first: Int, var second: Int) -> Int:
        self.calls += 1
        return first + second + self.calls


@fieldwise_init
struct FCOnceCombiner(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: ArcPointer[Int]
    def call_once(deinit self, var first: Int, var second: Int) -> Int:
        self.calls[] += 1
        return first + second


@fieldwise_init
struct FCOwner(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def fc_move(var a: FCOwner, var b: FCOwner) -> Int: return a.code + b.code


@fieldwise_init
struct FCApply(Unary, ImplicitlyCopyable):
    var factor: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var arg: Int) -> Int: return arg * self.factor


@fieldwise_init
struct FCMoveApply(OnceUnary):
    var capture: FCOwner
    comptime Arg = FCOwner
    comptime Out = Int
    def call_once(deinit self, var arg: FCOwner) -> Int:
        return self.capture.code + arg.code


def fc_ap_raise(value: Int) raises FCFailure -> Int: raise FCFailure(value)


def fc_application() raises:
    var functions: List[FCApply] = [FCApply(2), FCApply(3)]
    var values: List[Int] = [4, 5]
    assert_equal(pipeline(functions.copy()).ap(values.copy()).get(), [8, 10, 12, 15])
    assert_equal(pipeline(functions^).ap(List[Int]()).get(), List[Int]())
    assert_equal(pipeline(List[FCApply]()).ap(values^).get(), List[Int]())
    var optional = pipeline(Optional(FCApply(3))).ap(Optional(4)).get()
    assert_equal(optional.take(), 12)
    assert_false(pipeline(Optional[FCApply]()).ap(Optional(4)).get())
    assert_false(pipeline(Optional(FCApply(3))).ap(Optional[Int]()).get())
    assert_equal(pipeline[IdentityFamily](FCApply(2)).ap(6).get(), 12)
    assert_equal(pipeline[CellFamily](Cell(FCApply(2))).ap(Cell(6)).get().take(), 12)
    assert_equal(pipeline(Result[FCApply, String](Ok(FCApply(3)))).ap(Result[Int, String](Ok(5))).get().raise_on_err(), 15)
    var first = pipeline(Result[FCApply, String](Err(String("first")))).ap(Result[Int, String](Err(String("second")))).get()
    assert_equal(first^.fold_owned(fc_string_int, fc_identity), "first")
    var second = pipeline(Result[FCApply, String](Ok(FCApply(3)))).ap(Result[Int, String](Err(String("second")))).get()
    assert_equal(second^.fold_owned(fc_string_int, fc_identity), "second")
    var drops = ArcPointer(0)
    var owned = pipeline(Result[FCMoveApply, String](Ok(FCMoveApply(FCOwner(3, drops))))).ap(Result[FCOwner, String](Ok(FCOwner(4, drops)))).get()
    assert_equal(owned^.raise_on_err(), 7)
    assert_equal(drops[], 2)
    var skipped = pipeline(Result[FCMoveApply, String](Ok(FCMoveApply(FCOwner(3, drops))))).ap(Result[FCOwner, String](Err(String("skip")))).get()
    assert_equal(skipped^.fold_owned(fc_string_int, fc_identity), "skip")
    assert_equal(drops[], 3)
    var absent = pipeline(Optional[FCMoveApply]()).ap(Optional(FCOwner(4, drops))).get()
    assert_false(absent)
    assert_equal(drops[], 4)
    var error_code = 0
    try:
        _ = pipeline(Optional(as_unary(fc_ap_raise))).ap(Optional(71)).get()
    except error:
        comptime assert type_of(error) == FCFailure
        error_code = error.code
    assert_equal(error_code, 71)
    var calls = ArcPointer(0)
    def counted(value: Int) {calls} -> Int:
        calls[] += 1
        return value + 1
    var deferred = pipeline[Reader[Int]](Reader[Int].pure(as_unary(counted))).ap(Reader[Int].pure(8)).get()
    assert_equal(calls[], 0)
    assert_equal(run[Reader[Int]](deferred^, 0), 9)
    assert_equal(calls[], 1)
    var stateful = pipeline[State[Int]](State[Int].pure(FCApply(3))).ap(get[State[Int]]()).get()
    assert_equal(run[State[Int]](stateful^, 4), (12, 4))



def fc_three(a: Int, b: Int, c: Int) -> Int: return 100*a+10*b+c
def fc_one(a: Int) -> Int: return a+1
def fc_eight(a: Int,b: Int,c: Int,d: Int,e: Int,f: Int,g: Int,h: Int) -> Int:
    return a+b+c+d+e+f+g+h

def fc_three_move(var a: FCOwner,var b: FCOwner,var c: FCOwner) -> Int:
    return a.code+b.code+c.code

def fc_three_fail(var a: FCOwner,var b: FCOwner,var c: FCOwner) raises FCFailure -> Int:
    raise FCFailure(a.code+b.code+c.code)

@fieldwise_init
struct FCTupleCounter(MutableUnary):
    comptime Arg = Tuple[Int,Int,Int]
    comptime Out = Int
    var count: Int
    def call_mut(mut self, var arg: Self.Arg) -> Int:
        self.count += 1
        return arg[0]+arg[1]+arg[2]+self.count

@fieldwise_init
struct FCTupleOnce(OnceUnary):
    comptime Arg = Tuple[Int,Int,Int]
    comptime Out = Int
    var owned: FCOwner
    def call_once(deinit self,var arg: Self.Arg) -> Int:
        return arg[0]+arg[1]+arg[2]+self.owned.code


@fieldwise_init
struct FCLargeTuple(Unary):
    comptime Arg = Tuple[Int,Int,Int,Int,Int,Int,Int,Int,Int,Int]
    comptime Out = Int
    def call(self,var arg: Self.Arg) -> Int: return arg[0]+arg[9]


def fc_nary() raises:
    var single = pipeline(Optional(4)).product_n(()).get()
    assert_equal(single.value(), (4,))
    var one = pipeline(Optional(4)).map_n((), fc_one).get()
    assert_equal(one.value(),5)
    var two = pipeline(Optional(4)).map_n((Optional(5),),fc_add).get()
    assert_equal(two.value(),9)
    var eight = pipeline(Optional(1)).map_n((Optional(2),Optional(3),Optional(4),Optional(5),Optional(6),Optional(7),Optional(8)),fc_eight).get()
    assert_equal(eight.value(),36)
    assert_equal(pipeline[IdentityFamily](1).map_n((2,3,4,5,6,7,8),fc_eight).get(),36)
    # Families that keep pure carriers pure take any number of operands.
    var large = pipeline(Optional(1)).product_n((Optional(2),Optional(3),Optional(4),Optional(5),Optional(6),Optional(7),Optional(8),Optional(9),Optional(10))).get()
    assert_equal(large.value(),(1,2,3,4,5,6,7,8,9,10))
    var large_map = pipeline(Optional(1)).map_n((Optional(2),Optional(3),Optional(4),Optional(5),Optional(6),Optional(7),Optional(8),Optional(9),Optional(10)),FCLargeTuple()).get()
    assert_equal(large_map.value(),11)
    var large_list = pipeline(List[Int]([1])).product_n((List[Int]([2]),List[Int]([3]),List[Int]([4]),List[Int]([5]),List[Int]([6]),List[Int]([7]),List[Int]([8]),List[Int]([9]),List[Int]([10]))).get()
    assert_equal(large_list[0][9],10)
    var mixed = pipeline(Result[Int,String](Ok(1))).product_n((Result[String,String](Ok(String("text"))),Result[Bool,String](Ok(True)))).get()
    assert_equal(mixed^.raise_on_err(),(1,String("text"),True))
    var a:List[Int]=[1,2]
    var b:List[Int]=[3,4]
    var c:List[Int]=[5,6]
    assert_equal(pipeline(a.copy()).map_n((b.copy(),c.copy()),fc_three).get(),[135,136,145,146,235,236,245,246])
    assert_equal(pipeline(a.copy()).map_n((b.copy(),c.copy()),FCTupleCounter(0)).get(),[10,12,13,15,15,17,18,20])
    assert_equal(pipeline(a^).product_n((b^,c^)).get(),[(1,3,5),(1,3,6),(1,4,5),(1,4,6),(2,3,5),(2,3,6),(2,4,5),(2,4,6)])
    var empty = pipeline(fc_values()).map_n((List[Int](),fc_values()),fc_three).get()
    assert_equal(len(empty),0)
    var calls = ArcPointer(0)
    def count(a:Int,b:Int,c:Int) {calls} -> Int:
        calls[] += 1
        return a+b+c
    assert_false(pipeline(Optional(1)).map_n((Optional[Int](),Optional(3)),count).get())
    var failed = pipeline(Result[Int,String](Err(String("first")))).map_n((Result[Int,String](Err(String("second"))),Result[Int,String](Ok(3))),count).get()
    assert_equal(failed^.fold_owned(fc_string_int,fc_identity),"first")
    var second = pipeline(Result[Int,String](Ok(1))).map_n((Result[Int,String](Err(String("second"))),Result[Int,String](Err(String("third")))),count).get()
    assert_equal(second^.fold_owned(fc_string_int,fc_identity),"second")
    assert_equal(calls[],0)
    var drops = ArcPointer(0)
    var moved = pipeline(Result[FCOwner,String](Ok(FCOwner(1,drops)))).map_n((Result[FCOwner,String](Ok(FCOwner(2,drops))),Result[FCOwner,String](Ok(FCOwner(3,drops)))),fc_three_move).get()
    assert_equal(moved^.raise_on_err(),6)
    assert_equal(drops[],3)
    var skipped = pipeline(Optional(FCOwner(1,drops))).map_n((Optional[FCOwner](),Optional(FCOwner(3,drops))),fc_three_move).get()
    assert_false(skipped)
    assert_equal(drops[],5)
    var error_code = 0
    try:
        _=pipeline(Optional(FCOwner(1,drops))).map_n((Optional(FCOwner(2,drops)),Optional(FCOwner(3,drops))),fc_three_fail).get()
    except error:
        comptime assert type_of(error) == FCFailure
        error_code = error.code
    assert_equal(error_code,6)
    assert_equal(drops[],8)
    var once = pipeline(Result[Int,String](Ok(1))).map_n((Result[Int,String](Ok(2)),Result[Int,String](Ok(3))),FCTupleOnce(FCOwner(4,drops))).get()
    assert_equal(once^.raise_on_err(),10)
    assert_equal(drops[],9)
    var not_called = pipeline(Result[Int,String](Err(String("skip")))).map_n((Result[Int,String](Ok(2)),Result[Int,String](Ok(3))),FCTupleOnce(FCOwner(4,drops))).get()
    assert_equal(not_called^.fold_owned(fc_string_int,fc_identity),"skip")
    assert_equal(drops[],10)
    assert_equal(pipeline[IdentityFamily](1).map_n((2,3),fc_three).get(),123)
    assert_equal(pipeline[CellFamily](Cell(1)).map_n((Cell(2),Cell(3)),fc_three).get().take(),123)
    var deferred = pipeline[Reader[Int]](Reader[Int].pure(1)).map_n((Reader[Int].pure(2),Reader[Int].pure(3)),count).get()
    assert_equal(calls[],0)
    assert_equal(run[Reader[Int]](deferred^,7),6)
    assert_equal(calls[],1)
    var stateful = pipeline[State[Int]](get[State[Int]]()).product_n((modify[State[Int]](fc_one),get[State[Int]]())).get()
    var sequenced = run[State[Int]](stateful^,7)
    assert_equal(sequenced[0][0],7)
    comptime assert type_of(sequenced[0][1]) == NoneType
    assert_equal(sequenced[0][2],8)
    assert_equal(sequenced[1],8)
    var capture=FCOwner(10,drops)
    def captured(a:Int,b:Int,c:Int) {var capture^} -> Int:
        return capture.code+a+b+c
    var borrowed=pipeline[Reader[Int]](Reader[Int].pure(1)).map_n((Reader[Int].pure(2),Reader[Int].pure(3)),captured).get()
    assert_equal(run[Reader[Int]](borrowed^,0),16)
    assert_equal(drops[],10)
    _=captured^
    assert_equal(drops[],11)

def main() raises:
    fc_application()
    fc_nary()
    assert_equal(pipeline(fc_values()).map2(fc_seconds(), fc_add).get(), [11, 21, 12, 22])
    assert_equal(pipeline(fc_values()).product(fc_seconds()).get(), [(1, 10), (1, 20), (2, 10), (2, 20)])
    assert_equal(pipeline(fc_values()).map2(fc_seconds(), FCCombiner(0)).get(), [12, 23, 15, 26])
    assert_equal(pipeline(List[Int]()).map2(fc_seconds(), fc_add).get(), List[Int]())
    assert_false(pipeline(Optional[Int]()).map2(Optional(2), fc_add).get())
    var optional_pair = pipeline(Optional(3)).product(Optional(String("x"))).get()
    assert_equal(optional_pair.take(), (3, String("x")))
    assert_equal(pipeline[IdentityFamily](2).map2(4, fc_add).get(), 6)
    assert_equal(pipeline[IdentityFamily](2).product(4).get(), (2, 4))
    assert_equal(pipeline[CellFamily](Cell(2)).map2(Cell(4), fc_add).get().take(), 6)
    assert_equal(pipeline[CellFamily](Cell(2)).product(Cell(4)).get().take(), (2, 4))
    var direct = pipeline(Result[Int, String](Ok(3))).map2(Result[String, String](Ok(String("x"))), fc_text).get()
    assert_equal(direct^.raise_on_err(), "3x")
    var pair = pipeline(Result[Int, String](Ok(3))).product(Result[Int, String](Ok(4))).get()
    assert_equal(pair^.raise_on_err(), (3, 4))
    var fluent = pipeline(Result[Int, String](Ok(4))).map2(Result[Int, String](Ok(5)), fc_add).get()
    assert_equal(fluent^.raise_on_err(), 9)
    var calls = ArcPointer(0)
    def counted(a: Int, b: Int) {calls} -> Int:
        calls[] += 1
        return a + b
    var first = pipeline(Result[Int, String](Err(String("first")))).map2(Result[Int, String](Err(String("second"))), counted).get()
    assert_equal(first^.fold_owned(fc_string_int, fc_identity), "first")
    var second = pipeline(Result[Int, String](Ok(1))).map2(Result[Int, String](Err(String("second"))), counted).get()
    assert_equal(second^.fold_owned(fc_string_int, fc_identity), "second")
    assert_equal(calls[], 0)
    var code = 0
    try:
        _ = pipeline(Result[Int, String](Ok(1))).map2(Result[Int, String](Ok(2)), fc_raise)
    except error:
        code = error.code
    assert_equal(code, 3)
    var drops = ArcPointer(0)
    var moved = pipeline(Result[FCOwner, String](Ok(FCOwner(3, drops)))).product(Result[FCOwner, String](Ok(FCOwner(4, drops)))).get()
    var owners = moved^.raise_on_err()
    assert_equal(drops[], 0)
    assert_equal(owners[0].code + owners[1].code, 7)
    _ = owners^
    assert_equal(drops[], 2)
    var total = pipeline(Optional(FCOwner(5, drops))).map2(Optional(FCOwner(6, drops)), fc_move).get()
    assert_equal(total.take(), 11)
    assert_equal(drops[], 4)
    var owned = FCOwner(7, drops)
    def captured(a: Int, b: Int) {var owned^} -> Int:
        return owned.code + a + b
    var observed = pipeline(Result[Int, String](Ok(1))).map2(Result[Int, String](Ok(2)), captured).get()
    assert_equal(observed^.raise_on_err(), 10)
    assert_equal(drops[], 4)
    _ = captured^
    assert_equal(drops[], 5)
    var once = pipeline(Result[Int, String](Ok(1))).map2(Result[Int, String](Ok(2)), FCOnceCombiner(calls)).get()
    assert_equal(once^.raise_on_err(), 3)
    assert_equal(calls[], 1)


def fc_string_int(var value: Int) -> String: return String(value)
def fc_identity(var value: String) -> String: return value^


def fc_values() -> List[Int]: return [1, 2]
def fc_seconds() -> List[Int]: return [10, 20]
