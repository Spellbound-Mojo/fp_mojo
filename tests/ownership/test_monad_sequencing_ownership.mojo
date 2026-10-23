"""Single-use retention moves owners; branch disposal and abandonment clean up."""
from fp.functions import piped
from fp.iteration import iterated
from fp.effects import Reader, run
from fp.algebra import pure
from fp.callables import BorrowOnceCallable, OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false


@fieldwise_init
struct MSOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct MSOnce(BorrowOnceCallable):
    var owner: MSOwner
    var present: Bool
    comptime Payload = MSOwner
    comptime Result = Optional[Int]
    def invoke_once(deinit self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        if self.present: return Optional(payload.id)
        return None


@fieldwise_init
struct MSOnceFactory(OnceThunk):
    var owner: MSOwner
    comptime Out = Optional[MSOwner]
    def call_once(deinit self) -> Self.Out: return Optional(self.owner^)


@fieldwise_init
struct MSPairOnce(BorrowOnceCallable):
    var projected: MSOwner
    var present: Bool
    comptime Payload = MSOwner
    comptime Result = Optional[MSOwner]
    def invoke_once(deinit self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        if self.present: return Optional(self.projected^)
        return None


def mso_retention() raises:
    var values = ArcPointer(0)
    var captures = ArcPointer(0)
    var kept = piped(Optional(MSOwner(1,values))).flat_tap(MSOnce(MSOwner(0,captures),True)).get()
    assert_equal(kept.value().id,1)
    assert_equal(values[],0)
    assert_equal(captures[],1)
    _ = kept^
    assert_equal(values[],1)
    assert_false(piped(Optional(MSOwner(2,values))).flat_tap(MSOnce(MSOwner(0,captures),False)).get())
    assert_equal(values[],2)
    var earlier = piped(Optional(MSOwner(3,values))).before(MSOnceFactory(MSOwner(4,captures))).get()
    assert_equal(earlier.value().id,3)
    assert_equal(captures[],3)
    _ = earlier^
    assert_equal(values[],3)
    var next = piped(Optional(MSOwner(5,values))).followed_by(MSOnceFactory(MSOwner(6,captures))).get()
    assert_equal(next.value().id,6)
    assert_equal(values[],4)
    _ = next^
    assert_equal(captures[],4)
    assert_false(piped(Optional[MSOwner]()).before(MSOnceFactory(MSOwner(7,captures))).get())
    assert_equal(captures[],5)
    # Deferred retention moves its input through a once-only base effect.
    comptime R = Reader[Int]
    comptime RA = type_of(pure[R](0))
    def observe(value: MSOwner) -> RA: return pure[R](value.id)
    var delayed = piped(pure[R](MSOwner(8,values))).flat_tap[R](observe).get()
    assert_equal(values[],4)
    var environment = 0
    var owned = run[R](delayed^,environment)
    assert_equal(owned.id,8)
    _ = owned^
    assert_equal(values[],5)


def mso_cleanup() raises:
    var values = ArcPointer(0)
    var errors = ArcPointer(0)
    var captures = ArcPointer(0)
    var calls = ArcPointer(0)
    def raising() raises MSOwner {errors,calls} -> List[Int]:
        calls[] += 1
        raise MSOwner(9,errors)
    var pending = List[MSOwner]()
    pending.append(MSOwner(1,values))
    pending.append(MSOwner(2,values))
    var code = 0
    try:
        _ = piped(pending^).followed_by(raising).get()
    except error:
        comptime assert type_of(error) == MSOwner
        code = error.id
    assert_equal(code,9)
    assert_equal(calls[],1)
    assert_equal(values[],2)
    assert_equal(errors[],1)
    var token = MSOwner(3,captures)
    def produce() {var token^,calls,values} -> List[MSOwner]:
        calls[] += 1
        var output = List[MSOwner]()
        output.append(MSOwner(token.id,values))
        output.append(MSOwner(token.id+1,values))
        return output^
    var lazy = iterated(range(3)).before(produce^)
    assert_equal(calls[],1)
    assert_equal(lazy.__next__(),0)
    assert_equal(calls[],2)
    _ = lazy^
    assert_equal(calls[],2)
    assert_equal(values[],4)
    assert_equal(captures[],1)
    # Discarding source elements through followed_by never requires Copyable.
    var move_only = List[MSOwner]()
    move_only.append(MSOwner(4,values))
    def ints() -> List[Int]: return List[Int]([1])
    assert_equal(iterated(move_only^).followed_by(ints).to_list(),[1])
    assert_equal(values[],5)


def mso_pairing() raises:
    var originals = ArcPointer(0)
    var projections = ArcPointer(0)
    var pair = piped(Optional(MSOwner(1,originals))).flat_pair_with(MSPairOnce(MSOwner(2,projections),True)).get()
    assert_equal(pair.value()[0].id,1)
    assert_equal(pair.value()[1].id,2)
    assert_equal(originals[],0)
    assert_equal(projections[],0)
    _ = pair^
    assert_equal(originals[],1)
    assert_equal(projections[],1)
    assert_false(piped(Optional(MSOwner(3,originals))).flat_pair_with(MSPairOnce(MSOwner(4,projections),False)).get())
    assert_equal(originals[],2)
    assert_equal(projections[],2)
    assert_false(piped(Optional[MSOwner]()).flat_pair_with(MSPairOnce(MSOwner(5,projections),True)).get())
    assert_equal(projections[],3)
    # A branching projection moves each produced owner; only Int is copied.
    def branch(value: Int) {projections} -> List[MSOwner]:
        var output = List[MSOwner]()
        output.append(MSOwner(value+10,projections))
        output.append(MSOwner(value+20,projections))
        return output^
    var pairs = piped(List[Int]([1,2])).flat_pair_with(branch).get()
    assert_equal(len(pairs),4)
    assert_equal(pairs[3][0],2)
    assert_equal(pairs[3][1].id,22)
    assert_equal(projections[],3)
    _ = pairs^
    assert_equal(projections[],7)
    var lazy = iterated(range(3)).flat_pair_with(branch^)
    assert_equal(projections[],7)
    var first = lazy.__next__()
    assert_equal(first[0],0)
    assert_equal(first[1].id,10)
    _ = lazy^
    assert_equal(projections[],8)
    _ = first^
    assert_equal(projections[],9)


def main() raises:
    mso_retention()
    mso_cleanup()
    mso_pairing()
    print('monad sequencing ownership: ok')
