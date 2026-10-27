from std.testing import assert_equal
from fp.effects._transport import _ListenPair
from fp.callables import call_once, call_repeated
from std.memory import ArcPointer

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var trace: ArcPointer[String]
    def __deinit__(deinit self):
        self.trace[] += String(self.id)

def pair[first: Bool, repeated: Bool]() raises:
    var trace = ArcPointer(String())
    comptime C = _ListenPair[Owner, Owner, Owner, first]
    var function = C()
    for _ in range(2):
        comptime if repeated:
            var out = call_repeated(function, Tuple(Tuple(Owner(1, trace), Owner(2, trace)), Owner(3, trace)))
            _ = out^
        else:
            var out = call_once(C(), Tuple(Tuple(Owner(1, trace), Owner(2, trace)), Owner(3, trace)))
            _ = out^
    assert_equal(trace[], "123123" if first else "132132")

from fp.effects import Listen
from fp.effects._transport import _ListenMapped
from fp.algebra import IdentityFamily, StringMonoid
from fp.callables import Unary
from fp.callables.products import _take_pair
from std.builtin.rebind import rebind_var
from std.memory import MaybeUninit

struct Hearing[failure: Bool](Listen):
    comptime Family = IdentityFamily
    comptime Log = StringMonoid
    comptime TellAvailable = True
    comptime Told = NoneType
    comptime TellError = Never
    @staticmethod
    def tell(var log: String) -> NoneType: return None
    comptime ListenCompatible[V: Movable & Deinitable] = V == Owner
    comptime Listened[V: Movable & Deinitable] = Tuple[V, String]
    comptime ListenError[V: Movable & Deinitable] = Int if Self.failure else Never
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        comptime assert V == Owner
        var owner = rebind_var[Owner](value^)
        owner.trace[] += "l"
        comptime if Self.failure:
            comptime assert Self.ListenError[V] == Int
            raise rebind_var[Self.ListenError[V]](Int(71))
        return Tuple(rebind_var[V](owner^), String("heard"))

@fieldwise_init
struct Mapping[failure: Bool](Unary, Defaultable):
    comptime Arg = Tuple[Owner, String]
    comptime Out = Owner
    comptime Error = Int
    def call(self, var arg: Self.Arg) raises Int -> Owner:
        arg[0].trace[] += "m"
        comptime if Self.failure: raise 83
        var owner = MaybeUninit[Owner]()
        var log = MaybeUninit[String]()
        _take_pair(arg^, owner, log)
        _ = log^.unsafe_assume_init()
        return owner^.unsafe_assume_init()

def listening[hear_failure: Bool, map_failure: Bool]() raises:
    var trace = ArcPointer(String())
    comptime Operation = _ListenMapped[Hearing[hear_failure], Owner, Mapping[map_failure]]
    comptime assert Operation.Compatible[Owner]
    var code = 0
    try:
        var result = Operation().apply(Owner(1, trace))
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = rebind_var[Int](error^)
    assert_equal(code, 71 if hear_failure else 83 if map_failure else 0)
    assert_equal(trace[], "l1" if hear_failure else "lm1")

def origins[a: ImmOrigin, b: ImmOrigin, c: ImmOrigin](ref[a] left: Int, ref[b] right: Int, ref[c] log: Int) raises:
    comptime First = _ListenPair[Pointer[Int, a], Pointer[Int, b], Pointer[Int, c], True]
    var first = call_once(First(), Tuple(Tuple(Pointer(to=left), Pointer(to=right)), Pointer(to=log)))
    comptime assert type_of(first) == Tuple[Pointer[Int, a], Tuple[Pointer[Int, b], Pointer[Int, c]]]
    assert_equal(first[0], Pointer(to=left))
    assert_equal(first[1][0], Pointer(to=right))
    assert_equal(first[1][1], Pointer(to=log))
    comptime Second = _ListenPair[Pointer[Int, a], Pointer[Int, b], Pointer[Int, c], False]
    var second = call_once(Second(), Tuple(Tuple(Pointer(to=right), Pointer(to=left)), Pointer(to=log)))
    comptime assert type_of(second) == Tuple[Tuple[Pointer[Int, b], Pointer[Int, c]], Pointer[Int, a]]
    assert_equal(second[0][0], Pointer(to=right))
    assert_equal(second[0][1], Pointer(to=log))
    assert_equal(second[1], Pointer(to=left))

def main() raises:
    pair[True, False]()
    pair[False, False]()
    pair[True, True]()
    pair[False, True]()
    listening[False, False]()
    listening[True, False]()
    listening[False, True]()
    listening[True, True]()
    var left = 1
    var right = 2
    var log = 3
    origins(left, right, log)
