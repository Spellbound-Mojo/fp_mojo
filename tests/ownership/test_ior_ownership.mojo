"""Move-only Ior payloads, skipped owners, native failures and policy cleanup."""
from fp.data import Ior, Left, Right, Both, NonEmptyList
from fp.algebra import (IorFamily, IorValidationFamily, NonEmptyListSemigroup,
                        Semigroup, StringMonoid, ListFamily, map, flat_map,
                        map2_lazy, traverse)
from fp.callables import OnceUnary, OnceThunk, OnceBinary, MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct IOToken(Movable):
    var id: Int
    var drops: ArcPointer[List[Int]]
    def __deinit__(deinit self): self.drops[][self.id] += 1

comptime IOE = NonEmptyList[IOToken]
comptime IOR = Ior[IOE, IOToken]
comptime IOS = IorFamily[NonEmptyListSemigroup[IOToken]]
comptime IOV = IorValidationFamily[NonEmptyListSemigroup[IOToken]]

@fieldwise_init
struct IOBind(OnceUnary):
    var extra: IOToken
    var calls: ArcPointer[Int]
    comptime Arg = IOToken
    comptime Out = IOR
    def call_once(deinit self, var arg: IOToken) -> IOR:
        self.calls[] += 1
        return Both(NonEmptyList(self.extra^), arg^)

@fieldwise_init
struct IOThunk(OnceThunk):
    var value: IOR
    var calls: ArcPointer[Int]
    comptime Out = IOR
    def call_once(deinit self) -> IOR:
        self.calls[] += 1
        return self.value^

@fieldwise_init
struct IOCombine(OnceBinary):
    var owner: IOToken
    var calls: ArcPointer[Int]
    comptime First = IOToken
    comptime Second = IOToken
    comptime Out = IOToken
    def call_once(deinit self, var first: IOToken, var second: IOToken) -> IOToken:
        self.calls[] += 1
        return first^

@fieldwise_init
struct IOFailCombine(OnceBinary):
    var owner: IOToken
    comptime First = IOToken
    comptime Second = IOToken
    comptime Out = IOToken
    comptime Error = String
    def call_once(deinit self, var first: IOToken, var second: IOToken) raises String -> IOToken:
        if first.id == 1: raise String("binary failure")
        return first^

struct IOReject(Semigroup):
    comptime Value = IOE
    comptime Error = String
    @staticmethod
    def combine(var first: IOE, var second: IOE) raises String -> IOE:
        raise String("policy failure")

def io_raise(var value: IOToken) raises String -> IOToken:
    if value.id == 1: raise String("callback failure")
    return value^

@fieldwise_init
struct IOVisit(MutableUnary):
    var calls: ArcPointer[Int]
    var drops: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = IOR
    def call_mut(mut self, var arg: Int) -> IOR:
        self.calls[] += 1
        if arg == 2: return Left(NonEmptyList(IOToken(arg, self.drops)))
        return Right(IOToken(arg, self.drops))

def main() raises:
    var drops = ArcPointer(List[Int]([0, 0, 0, 0, 0]))
    var calls = ArcPointer(0)
    var combined_calls = ArcPointer(0)
    var value: IOR = Both(NonEmptyList(IOToken(0, drops)), IOToken(1, drops))
    var bound = flat_map[IOS](IOBind(IOToken(2, drops), calls), value^)
    assert_equal(calls[], 1)
    assert_equal(len(bound[Both[IOE, IOToken]].left), 2)
    assert_equal(bound[Both[IOE, IOToken]].right.id, 1)
    assert_equal(drops[], [0, 0, 0, 0, 0])
    _ = bound^
    assert_equal(drops[], [1, 1, 1, 0, 0])
    drops[] = [0, 0, 0, 0, 0]
    calls[] = 0
    var skipped = flat_map[IOS](IOBind(IOToken(2, drops), calls), IOR(Left(NonEmptyList(IOToken(0, drops)))))
    assert_equal(calls[], 0)
    assert_equal(drops[], [0, 0, 1, 0, 0])
    _ = skipped^
    assert_equal(drops[], [1, 0, 1, 0, 0])
    for accumulating in range(2):
        drops[] = [0, 0, 0, 0, 0]
        calls[] = 0
        combined_calls[] = 0
        var left: IOR = Left(NonEmptyList(IOToken(0, drops)))
        var right: IOR = Both(NonEmptyList(IOToken(2, drops)), IOToken(1, drops))
        var result: IOR
        if accumulating:
            result = map2_lazy[IOV](IOCombine(IOToken(3, drops), combined_calls), left^, IOThunk(right^, calls))
        else:
            result = map2_lazy[IOS](IOCombine(IOToken(3, drops), combined_calls), left^, IOThunk(right^, calls))
        assert_equal(calls[], accumulating)
        assert_equal(combined_calls[], 0)
        assert_equal(drops[], [0, 1, 0 if accumulating else 1, 1, 0])
        _ = result^
        assert_equal(drops[], [1, 1, 1, 1, 0])
    drops[] = [0, 0, 0, 0, 0]
    var two_values = map2_lazy[IOV](IOCombine(IOToken(4, drops), combined_calls),
        IOR(Both(NonEmptyList(IOToken(0, drops)), IOToken(1, drops))),
        IOThunk(IOR(Both(NonEmptyList(IOToken(2, drops)), IOToken(3, drops))), calls))
    assert_equal(drops[], [0, 0, 0, 1, 1])
    assert_equal(len(two_values[Both[IOE, IOToken]].left), 2)
    assert_equal(two_values[Both[IOE, IOToken]].right.id, 1)
    _ = two_values^
    assert_equal(drops[], [1, 1, 1, 1, 1])
    drops[] = [0, 0, 0, 0, 0]
    var binary_raised = False
    try:
        _ = map2_lazy[IOV](IOFailCombine(IOToken(4, drops)),
            IOR(Both(NonEmptyList(IOToken(0, drops)), IOToken(1, drops))),
            IOThunk(IOR(Both(NonEmptyList(IOToken(2, drops)), IOToken(3, drops))), calls))
    except error:
        binary_raised = True
        assert_equal(error, "binary failure")
    assert_true(binary_raised)
    assert_equal(drops[], [1, 1, 1, 1, 1])
    drops[] = [0, 0, 0, 0, 0]
    var raised = False
    try:
        _ = map[IOS](io_raise, IOR(Both(NonEmptyList(IOToken(0, drops)), IOToken(1, drops))))
    except error:
        raised = True
        assert_equal(error, "callback failure")
    assert_true(raised)
    assert_equal(drops[], [1, 1, 0, 0, 0])
    drops[] = [0, 0, 0, 0, 0]
    raised = False
    try:
        _ = flat_map[IorFamily[IOReject]](IOBind(IOToken(2, drops), calls),
            IOR(Both(NonEmptyList(IOToken(0, drops)), IOToken(1, drops))))
    except error:
        raised = True
        assert_equal(error, "policy failure")
    assert_true(raised)
    assert_equal(drops[], [1, 1, 1, 0, 0])
    drops[] = [0, 0, 0, 0, 0]
    calls[] = 0
    var collected = traverse[ListFamily, IOV](IOVisit(calls, drops), List[Int]([0, 1, 2, 3]))
    assert_equal(calls[], 4)
    assert_equal(drops[], [1, 1, 0, 1, 0])
    assert_equal(collected[Left[IOE]].value.first().id, 2)
    _ = collected^
    assert_equal(drops[], [1, 1, 1, 1, 0])
    drops[] = [0, 0, 0, 0, 0]
    var left_value: IOR = Left(NonEmptyList(IOToken(0, drops)))
    var diagnostics = left_value^.unwrap[Left[IOE]]().into_payload()
    assert_equal(diagnostics.first().id, 0)
    var right_value: IOR = Right(IOToken(1, drops))
    var payload = right_value^.unwrap[Right[IOToken]]().into_payload()
    assert_equal(payload.id, 1)
    var both_value: IOR = Both(NonEmptyList(IOToken(2, drops)), IOToken(3, drops))
    var pair = both_value^.unwrap[Both[IOE, IOToken]]().into_payload()
    assert_equal(pair[0].first().id, 2)
    assert_equal(pair[1].id, 3)
    assert_equal(drops[], [0, 0, 0, 0, 0])
    _ = diagnostics^
    _ = payload^
    _ = pair^
    assert_equal(drops[], [1, 1, 1, 1, 0])
    print("ior ownership: ok")
