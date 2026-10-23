"""Ordered validation preserves native Result types and independent failures."""
from fp.algebra import (Semigroup, Monoid, ValidationFamily, ResultFamily, ListFamily,
                        ListMonoid, StringMonoid, combine, map2_lazy, traverse)
from fp.callables import Binary, OnceThunk, MutableUnary, OnceUnary
from fp.data import Result, Ok, Err
from fp.functions import piped, kleisli
from fp.iteration import iterated
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false

comptime PVResult = Result[Int, List[String]]
comptime PVFamily = ValidationFamily[ListMonoid[String]]


def pv_validate(value: Int) -> PVResult:
    if value < 0:
        var errors: List[String] = [String(value)]
        return Err(errors^)
    return Ok(value)


def pv_add(a: Int, b: Int) -> Int: return a+b
def pv_three(a: Int, b: Int, c: Int) -> Int: return 100*a+10*b+c
def pv_one(a: Int) -> Int: return a+1


struct PVJoin(Semigroup):
    comptime Value = String
    @staticmethod
    def combine(var left: String, var right: String) -> String:
        left += right
        return left^


@fieldwise_init
struct PVNativeFailure(Movable):
    var code: Int


struct PVFailJoin(Semigroup):
    comptime Value = String
    comptime Error = PVNativeFailure
    @staticmethod
    def combine(var left: String, var right: String) raises Self.Error -> String:
        raise PVNativeFailure(left.byte_length()+right.byte_length())


@fieldwise_init
struct PVAdd(Binary, Copyable, Defaultable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int: return first+second


@fieldwise_init
struct PVRight(OnceThunk):
    var calls: ArcPointer[Int]
    var value: PVResult
    comptime Out = PVResult
    def call_once(deinit self) -> Self.Out:
        self.calls[] += 1
        return self.value^


@fieldwise_init
struct PVCount(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = PVResult
    def call_mut(mut self, var arg: Int) -> PVResult:
        self.calls[] += 1
        return pv_validate(arg)


@fieldwise_init
struct PVConstructor(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Tuple[Int,Int,Int]
    comptime Out = Int
    def call_once(deinit self, var arg: Self.Arg) -> Int:
        self.calls[] += 1
        return pv_three(arg[0],arg[1],arg[2])


@fieldwise_init
struct PVNine(OnceUnary, Defaultable):
    comptime Arg=Tuple[Int,Int,Int,Int,Int,Int,Int,Int,Int]
    comptime Out=Int
    def call_once(deinit self,var arg:Self.Arg)->Int:return arg[0]+arg[8]

@fieldwise_init
struct PVSingle(OnceUnary, Defaultable):
    comptime Arg=Tuple[Int]
    comptime Out=Int
    def call_once(deinit self,var arg:Self.Arg)->Int:return arg[0]


def pv_nary() raises:
    var calls = ArcPointer(0)
    var result = pv_validate(1).par_map_n((pv_validate(2),pv_validate(3)), PVConstructor(calls))
    comptime assert type_of(result) == PVResult
    assert_equal(result._ok().value, 123)
    assert_equal(calls[], 1)
    var invalid = pv_validate(-1).par_map_n((pv_validate(2),pv_validate(-3)), PVConstructor(calls))
    assert_equal(invalid._err().value, [String('-1'),String('-3')])
    assert_equal(calls[], 1)
    assert_equal(pv_validate(1).par_map_n((pv_validate(2),pv_validate(3)), pv_three)._ok().value, 123)
    assert_equal(pv_validate(1).par_map_n(Tuple(),pv_one)._ok().value, 2)
    assert_equal(pv_validate(-1).par_map_n((pv_validate(-2),),pv_add)._err().value, [String('-1'),String('-2')])
    assert_equal(pv_validate(-1).par_map_n((pv_validate(2),),pv_add)._err().value, [String('-1')])
    assert_equal(pv_validate(1).par_map_n((pv_validate(-2),),pv_add)._err().value, [String('-2')])
    assert_equal(piped(pv_validate(-1)).par_map_n((pv_validate(-2),pv_validate(-3)),pv_three).get()._err().value,
                 [String('-1'),String('-2'),String('-3')])
    # The empty error list is a stored failure, not the neutral success.
    var empty_error = PVResult(Err(List[String]())).par_map_n((pv_validate(2),),pv_add)
    assert_true(empty_error.is_err())
    assert_equal(len(empty_error._err().value), 0)
    # Explicit policy preserves scalar errors; no list conversion is implicit.
    comptime R = Result[Int,String]
    var joined = R(Err(String('a'))).par_map_n[PVJoin]((R(Ok(2)),R(Err(String('b')))),pv_three)
    comptime assert type_of(joined) == R
    assert_equal(joined._err().value, 'ab')
    assert_equal(piped(R(Err(String('a')))).par_map_n[PVJoin]((R(Err(String('b'))),),pv_add).get()._err().value,'ab')
    assert_equal(combine[PVJoin](String('a'),String('b')),'ab')
    comptime assert conforms_to(StringMonoid, Semigroup)
    comptime assert conforms_to(ListMonoid[Int], Monoid)
    assert_equal(combine[PVJoin](combine[PVJoin](String('a'),String('b')),String('c')),
                 combine[PVJoin](String('a'),combine[PVJoin](String('b'),String('c'))))
    var code = 0
    try:
        _ = R(Err(String('a'))).par_map_n[PVFailJoin]((R(Err(String('bc'))),),pv_add)
    except error:
        comptime assert type_of(error) == PVNativeFailure
        code = error.code
    assert_equal(code, 3)
    assert_equal(pv_validate(1).par_map_n((pv_validate(2),pv_validate(3),pv_validate(4),pv_validate(5),pv_validate(6),pv_validate(7),pv_validate(8),pv_validate(9)),PVNine())._ok().value,10)
    assert_equal(R(Ok(4)).par_map_n[PVFailJoin](Tuple(),PVSingle())._ok().value,4)
    # No combine happens for one operand, so the native effect remains Never.
    assert_equal(R(Ok(4)).par_map_n[PVFailJoin](Tuple(),pv_one)._ok().value,5)


def pv_traversal() raises:
    var calls = ArcPointer(0)
    var values: List[Int] = [1,-2,3,-4]
    var gathered = piped(values.copy()).par_traverse(PVCount(calls)).get()
    assert_equal(calls[],4)
    assert_equal(gathered._err().value,[String('-2'),String('-4')])
    calls[] = 0
    var ordinary = piped(values^).traverse[ResultFamily[List[String]]](PVCount(calls)).get()
    assert_equal(ordinary._err().value,[String('-2')])
    assert_equal(calls[],2)
    calls[] = 0
    var empty = iterated(List[Int]()).par_traverse(PVCount(calls))
    assert_true(empty.is_ok())
    assert_equal(len(empty._ok().value),0)
    assert_equal(calls[],0)
    var items: List[Int] = [9,1,2,3]
    var iterator = items^.__iter__()
    _ = iterator.__next__()
    var collected = iterated(iterator^).par_traverse(pv_validate)
    assert_equal(collected._ok().value,[1,2,3])
    var chain = kleisli[ResultFamily[List[String]]](pv_validate).map(pv_one)
    assert_equal(iterated(List[Int]([1,2])).par_traverse(chain)._ok().value,[2,3])
    assert_equal(piped(List[Int]([-1,-2])).par_traverse(chain).get()._err().value,[String('-1'),String('-2')])
    var absent = piped(Optional[Int]()).par_traverse(PVCount(calls)).get()
    assert_true(absent.is_ok())
    assert_false(absent._ok().value)
    assert_equal(calls[],0)
    var present = piped(Optional(3)).par_traverse(pv_validate).get()
    assert_equal(present._ok().value.value(),3)
    var source_err = piped(Result[Int,String](Err(String('source')))).par_traverse(PVCount(calls)).get()
    comptime assert type_of(source_err) == Result[Result[Int,String],List[String]]
    assert_true(source_err.is_ok())
    assert_equal(source_err._ok().value._err().value,'source')
    assert_equal(calls[],0)
    var source_ok = piped(Result[Int,String](Ok(-2))).par_traverse(pv_validate).get()
    assert_equal(source_ok._err().value,[String('-2')])
    def scalar(value: Int) -> Result[Int,String]: return Err(String(value))
    assert_equal(iterated(range(3)).par_traverse[PVJoin](scalar)._err().value,'012')
    assert_equal(piped(List[Int]([0,1,2])).par_traverse[PVJoin](scalar).get()._err().value,'012')
    # A native raise stops later callbacks even after stored failures.
    def raising(value: Int) raises PVNativeFailure {calls} -> PVResult:
        calls[] += 1
        if value == -3: raise PVNativeFailure(7)
        return pv_validate(value)
    var code = 0
    try:
        _ = iterated(List[Int]([-1,-2,-3,-4])).par_traverse(raising)
    except error:
        comptime assert type_of(error) == PVNativeFailure
        code = error.code
    assert_equal(code,7)
    assert_equal(calls[],3)
    calls[] = 0
    var combined = map2_lazy[PVFamily](PVAdd(),pv_validate(-1),PVRight(calls,pv_validate(-2)))
    assert_equal(calls[],1)
    assert_equal(combined._err().value,[String('-1'),String('-2')])
    _ = map2_lazy[ResultFamily[List[String]]](PVAdd(),pv_validate(-1),PVRight(calls,pv_validate(-2)))
    assert_equal(calls[],1)


def pv_products() raises:
    comptime Text = Result[String,List[String]]
    var product = pv_validate(1).par_product_n((Text(Ok(String('two'))),pv_validate(3)))
    comptime assert type_of(product) == Result[Tuple[Int,String,Int],List[String]]
    assert_equal(product._ok().value[0],1)
    assert_equal(product._ok().value[1],'two')
    assert_equal(product._ok().value[2],3)
    var eager = piped(pv_validate(4)).par_product_n((Text(Ok(String('five'))),)).get()
    assert_equal(eager._ok().value[1],'five')
    var errors = pv_validate(-1).par_product_n((pv_validate(2),pv_validate(-3)))
    assert_equal(errors._err().value,[String('-1'),String('-3')])
    assert_equal(piped(pv_validate(-1)).par_product_n((pv_validate(-2),)).get()._err().value,
                 [String('-1'),String('-2')])
    var empty_error = PVResult(Err(List[String]())).par_product_n((pv_validate(1),))
    assert_true(empty_error.is_err())
    assert_equal(len(empty_error._err().value),0)
    comptime R = Result[Int,String]
    var joined = R(Err(String('a'))).par_product_n[PVJoin]((R(Ok(1)),R(Err(String('b')))))
    assert_equal(joined._err().value,'ab')
    assert_equal(piped(R(Err(String('a')))).par_product_n[PVJoin]((R(Err(String('b'))),)).get()._err().value,'ab')
    # Products have no native callback arity boundary, including explicit policies.
    var nine = pv_validate(1).par_product_n((pv_validate(2),pv_validate(3),pv_validate(4),pv_validate(5),pv_validate(6),pv_validate(7),pv_validate(8),pv_validate(9)))
    assert_equal(nine._ok().value[8],9)
    var custom_nine = R(Ok(1)).par_product_n[PVJoin]((R(Ok(2)),R(Ok(3)),R(Ok(4)),R(Ok(5)),R(Ok(6)),R(Ok(7)),R(Ok(8)),R(Ok(9))))
    assert_equal(custom_nine._ok().value[8],9)
    # No combination is possible with no additional operands: exact Never effect.
    var single = R(Ok(4)).par_product_n[PVFailJoin](Tuple())
    comptime assert type_of(single) == Result[Tuple[Int],String]
    assert_equal(single._ok().value[0],4)
    assert_equal(piped(R(Err(String('a')))).par_product_n[PVFailJoin](Tuple()).get()._err().value,'a')
    assert_equal(pv_validate(5).par_product_n(Tuple())._ok().value[0],5)
    var code = 0
    try:
        _ = R(Err(String('a'))).par_product_n[PVFailJoin]((R(Err(String('bc'))),))
    except error:
        comptime assert type_of(error) == PVNativeFailure
        code = error.code
    assert_equal(code,3)


def pv_sequences() raises:
    var values:List[PVResult] = [pv_validate(1),pv_validate(2)]
    var gathered = piped(values^).par_sequence().get()
    comptime assert type_of(gathered) == Result[List[Int],List[String]]
    assert_equal(gathered._ok().value,[1,2])
    var errors:List[PVResult] = [pv_validate(-1),pv_validate(2),pv_validate(-3)]
    assert_equal(piped(errors^).par_sequence().get()._err().value,[String('-1'),String('-3')])
    var remaining:List[PVResult] = [pv_validate(-9),pv_validate(1),pv_validate(2)]
    var source = remaining^.__iter__()
    _ = source.__next__()
    assert_equal(iterated(source^).par_sequence()._ok().value,[1,2])
    var all_errors:List[PVResult] = [pv_validate(-1),pv_validate(-2)]
    assert_equal(iterated(all_errors^).par_sequence()._err().value,[String('-1'),String('-2')])
    assert_equal(len(piped(List[PVResult]()).par_sequence().get()._ok().value),0)
    assert_equal(len(iterated(List[PVResult]()).par_sequence()._ok().value),0)
    var empty_errors:List[PVResult] = [PVResult(Err(List[String]())),pv_validate(2)]
    assert_true(iterated(empty_errors^).par_sequence().is_err())
    var absent = piped(Optional[PVResult]()).par_sequence().get()
    comptime assert type_of(absent) == Result[Optional[Int],List[String]]
    assert_false(absent._ok().value)
    assert_equal(piped(Optional(pv_validate(7))).par_sequence().get()._ok().value.value(),7)
    assert_equal(piped(Optional(pv_validate(-7))).par_sequence().get()._err().value,[String('-7')])
    comptime Source = Result[PVResult,String]
    var source_error = piped(Source(Err(String('source')))).par_sequence().get()
    comptime assert type_of(source_error) == Result[Result[Int,String],List[String]]
    assert_equal(source_error._ok().value._err().value,'source')
    assert_equal(piped(Source(Ok(pv_validate(7)))).par_sequence().get()._ok().value._ok().value,7)
    assert_equal(piped(Source(Ok(pv_validate(-7)))).par_sequence().get()._err().value,[String('-7')])
    comptime R = Result[Int,String]
    var scalar_errors:List[R] = [R(Err(String('a'))),R(Ok(2)),R(Err(String('b')))]
    assert_equal(iterated(scalar_errors.copy()).par_sequence[PVJoin]()._err().value,'ab')
    assert_equal(piped(scalar_errors^).par_sequence[PVJoin]().get()._err().value,'ab')
    # Sources with at most one element never combine errors, even with a raising policy.
    assert_false(piped(Optional[R]()).par_sequence[PVFailJoin]().get()._ok().value)
    assert_equal(piped(Optional(R(Ok(8)))).par_sequence[PVFailJoin]().get()._ok().value.value(),8)
    assert_equal(piped(Result[R,Int](Err(9))).par_sequence[PVFailJoin]().get()._ok().value._err().value,9)
    var pulls = ArcPointer(0)
    def failed(value:Int) {pulls} -> R:
        pulls[] += 1
        return Err(String(value))
    var code = 0
    try:
        _ = iterated(range(4)).map(failed).par_sequence[PVFailJoin]()
    except error:
        comptime assert type_of(error) == PVNativeFailure
        code = error.code
    assert_equal(code,2)
    assert_equal(pulls[],2)
    var pending:List[R] = [R(Err(String('a'))),R(Err(String('bc')))]
    try:
        _ = piped(pending^).par_sequence[PVFailJoin]().get()
    except error:
        comptime assert type_of(error) == PVNativeFailure
        code = error.code
    assert_equal(code,3)


def main() raises:
    pv_nary()
    pv_traversal()
    pv_products()
    pv_sequences()
    print('parallel validation: ok')
