from std.testing import assert_equal
from fp.algebra import Semigroup, ValidationFamily, ResultFamily, combine, map2
from fp.algebra.ior import _ior_merge
from fp.data import Result, Ok, Err
from fp.iteration import combine_all_optional
from fp.callables import OnceBinary
from std.memory import ArcPointer

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var trace: ArcPointer[String]
    def __deinit__(deinit self): self.trace[] += String(self.id)

struct Merge[fail: Bool](Semigroup):
    comptime Value = Owner
    comptime Error = Int
    @staticmethod
    def combine(var first: Owner, var second: Owner) raises Int -> Owner:
        first.trace[] += "s"
        if Self.fail: raise 71
        return first^

@fieldwise_init
struct Add[fail: Bool](OnceBinary):
    var owner: Owner
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self, var first: Int, var second: Int) raises Int -> Int:
        self.owner.trace[] += "f"
        if Self.fail: raise 83
        return first + second

def direct[fail: Bool]() raises:
    var trace = ArcPointer(String())
    var code = 0
    try:
        var value = combine[Merge[fail]](Owner(1, trace), Owner(2, trace))
        _ = value^
    except error: code = error
    assert_equal(code, 71 if fail else 0)
    assert_equal(trace[], "2s1")

def optional[fail: Bool](left: Bool, right: Bool) raises:
    var trace = ArcPointer(String())
    var first = Optional[Owner]()
    var second = Optional[Owner]()
    if left: first = Owner(1, trace)
    if right: second = Owner(2, trace)
    var code = 0
    try:
        var value = _ior_merge[Merge[fail], Int](first^, second^)
        _ = value^
    except error: code = error
    assert_equal(code, 71 if fail and left and right else 0)
    assert_equal(trace[], "2s1" if left and right else "1" if left else "2" if right else "")

def validation[fail: Bool, callback_fail: Bool](left: Bool, right: Bool) raises:
    var trace = ArcPointer(String())
    comptime R = Result[Int, Owner]
    var code = 0
    var first: R
    var second: R
    if left: first = Ok(1)
    else: first = Err(Owner(1, trace))
    if right: second = Ok(2)
    else: second = Err(Owner(2, trace))
    try:
        var value = map2[ValidationFamily[Merge[fail]]](Add[callback_fail](Owner(3, trace)), first^, second^)
        _ = value^
    except error: code = error
    var expected: String
    var expected_code = 0
    if left and right:
        expected = "f3"
        expected_code = 83 if callback_fail else 0
    elif not left and not right:
        expected = "2s13" if fail else "2s31"
        expected_code = 71 if fail else 0
    else:
        expected = "32" if left else "31"
    assert_equal(code, expected_code)
    assert_equal(trace[], expected)

def sequential() raises:
    var trace = ArcPointer(String())
    comptime R = Result[Int, Owner]
    var value = map2[ResultFamily[Owner]](Add[False](Owner(3, trace)), R(Err(Owner(1, trace))), R(Err(Owner(2, trace))))
    _ = value^
    assert_equal(trace[], "321")

def terminal[fail: Bool](size: Int) raises:
    var trace = ArcPointer(String())
    var values = List[Owner]()
    for index in range(size): values.append(Owner(index + 1, trace))
    var code = 0
    var present = False
    var first = 0
    try:
        var result = combine_all_optional[Merge[fail]](values^)
        present = Bool(result)
        if result: first = result.value().id
        _ = result^
    except error: code = error
    var failed = fail and size > 1
    assert_equal(code, 71 if failed else 0)
    assert_equal(present, size > 0 and not failed)
    assert_equal(first, 1 if size > 0 and not failed else 0)
    var expected = ""
    if size == 1: expected = "1"
    elif size == 2: expected = "2s1"
    elif size == 3: expected = "2s13" if fail else "2s3s1"
    assert_equal(trace[], expected)

struct Borrowed[o: ImmOrigin](Semigroup):
    comptime Value = Pointer[Int, Self.o]
    comptime Error = Self.Value
    @staticmethod
    def combine(var first: Self.Value, var second: Self.Value) raises Self.Error -> Self.Value:
        if first[] < 0: raise second
        return first

def origins[o: ImmOrigin](ref[o] value: Int) raises:
    var caught = False
    var correct: Bool
    try:
        var result = combine[Borrowed[o]](Pointer(to=value), Pointer(to=value))
        comptime assert type_of(result) == Pointer[Int, o]
        correct = result == Pointer(to=value)
    except error:
        comptime assert type_of(error) == Pointer[Int, o]
        caught = True
        correct = error == Pointer(to=value)
    assert_equal(correct, True)
    assert_equal(caught, value < 0)

@fieldwise_init
struct OwnedCombine[fail: Bool](OnceBinary):
    var owner: Owner
    comptime First = Owner
    comptime Second = Owner
    comptime Out = Owner
    comptime Error = Int
    def call_once(deinit self, var first: Owner, var second: Owner) raises Int -> Owner:
        self.owner.trace[] += "f"
        if Self.fail: raise 83
        return first^

def values[accumulating: Bool, policy_fail: Bool, callback_fail: Bool](left: Bool, right: Bool) raises:
    var trace = ArcPointer(String())
    comptime R = Result[Owner,Owner]
    var first: R
    var second: R
    if left: first = Ok(Owner(1,trace))
    else: first = Err(Owner(1,trace))
    if right: second = Ok(Owner(2,trace))
    else: second = Err(Owner(2,trace))
    var code = 0
    var kind = 0
    var retained = 0
    try:
        var result: R
        comptime if accumulating:
            result = map2[ValidationFamily[Merge[policy_fail]]](OwnedCombine[callback_fail](Owner(3,trace)),first^,second^)
        else:
            result = map2[ResultFamily[Owner]](OwnedCombine[callback_fail](Owner(3,trace)),first^,second^)
        if result.is_ok():
            kind = 1
            retained = result._ok().value.id
        else:
            kind = 2
            retained = result._err().value.id
        _ = result^
    except error: code = error
    var expected_code = 0
    var expected_kind = 2
    var expected_retained = 2 if left else 1
    var expected_trace = "312" if left else "321"
    if left and right:
        expected_code = 83 if callback_fail else 0
        expected_kind = 0 if callback_fail else 1
        expected_retained = 0 if callback_fail else 1
        expected_trace = "2f31"
    elif accumulating and not left and not right:
        expected_code = 71 if policy_fail else 0
        expected_kind = 0 if policy_fail else 2
        expected_retained = 0 if policy_fail else 1
        expected_trace = "2s13" if policy_fail else "2s31"
    assert_equal(code,expected_code)
    assert_equal(kind,expected_kind)
    assert_equal(retained,expected_retained)
    assert_equal(trace[],expected_trace)

def main() raises:
    direct[False]()
    direct[True]()
    for left in [False, True]:
        for right in [False, True]:
            optional[False](left, right)
            optional[True](left, right)
            validation[False, False](left, right)
            validation[True, False](left, right)
            validation[False, True](left, right)
            validation[True, True](left, right)
    sequential()
    for size in range(4):
        terminal[False](size)
        terminal[True](size)
    var success = 1
    var failure = -1
    origins(success)
    origins(failure)
    for left in [False,True]:
        for right in [False,True]:
            values[True,False,False](left,right)
            values[True,True,False](left,right)
            values[True,False,True](left,right)
            values[True,True,True](left,right)
            values[False,False,False](left,right)
            values[False,False,True](left,right)
