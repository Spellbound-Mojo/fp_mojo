"""Native Ior failures remain raised and stop evaluation at their source."""
from fp.data import Ior, Left, Both
from fp.algebra import (IorFamily, IorValidationFamily, StringMonoid, Semigroup,
                        ListFamily, map2_lazy, traverse)
from fp.callables import OnceThunk, Binary, MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

struct IEPolicy(Semigroup):
    comptime Value = String
    comptime Error = String
    @staticmethod
    def combine(var left: String, var right: String) raises String -> String:
        raise String("policy")

@fieldwise_init
struct IEThunk(OnceThunk):
    var calls: ArcPointer[Int]
    var fails: Bool
    comptime Out = Ior[String, Int]
    comptime Error = String
    def call_once(deinit self) raises String -> Self.Out:
        self.calls[] += 1
        if self.fails: raise String("thunk")
        return Both(String("later"), 3)

@fieldwise_init
struct IEAdd(Binary):
    var calls: ArcPointer[Int]
    var fails: Bool
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = String
    def call(self, var first: Int, var second: Int) raises String -> Int:
        self.calls[] += 1
        if self.fails: raise String("combiner")
        return first + second

@fieldwise_init
struct IEVisit(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Ior[String, Int]
    comptime Error = String
    def call_mut(mut self, var arg: Int) raises String -> Self.Out:
        self.calls[] += 1
        if arg == 2: raise String("visit")
        return Left(String(arg))

def main() raises:
    var calls = ArcPointer(0)
    var combines = ArcPointer(0)
    var skipped = map2_lazy[IorFamily[IEPolicy]](IEAdd(combines, True),
        Ior[String, Int](Left(String("stored"))), IEThunk(calls, True))
    assert_equal(skipped[Left[String]].value, "stored")
    assert_equal(calls[], 0)
    assert_equal(combines[], 0)
    for mode in range(3):
        calls[] = 0
        combines[] = 0
        var raised = False
        try:
            _ = map2_lazy[IorValidationFamily[IEPolicy]](IEAdd(combines, mode == 1),
                Ior[String, Int](Both(String("stored"), 2)), IEThunk(calls, mode == 0))
        except error:
            raised = True
            assert_equal(error, "thunk" if mode == 0 else ("combiner" if mode == 1 else "policy"))
        assert_true(raised)
        assert_equal(calls[], 1)
        assert_equal(combines[], 0 if mode == 0 else 1)
    calls[] = 0
    var raised = False
    try:
        _ = traverse[ListFamily, IorValidationFamily[StringMonoid]](IEVisit(calls), List[Int]([0, 1, 2, 3]))
    except error:
        raised = True
        assert_equal(error, "visit")
    assert_true(raised)
    assert_equal(calls[], 3)
    print("ior native errors: ok")
