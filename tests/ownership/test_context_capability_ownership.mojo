from fp.functions import pipeline
from fp.effects import Reader, run
from fp.algebra import pure, NonEmptyListFamily
from fp.data import NonEmptyList
from fp.callables import BorrowOnceCallable, OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Once(BorrowOnceCallable):
    var owner: Owner
    var present: Bool
    comptime Payload = Owner
    comptime Result = Optional[Owner]
    def invoke_once(deinit self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        if self.present: return Optional(self.owner^)
        return None

@fieldwise_init
struct Factory(OnceThunk):
    var owner: Owner
    comptime Out = Optional[Owner]
    def call_once(deinit self) -> Self.Out: return Optional(self.owner^)

def main() raises:
    var values=ArcPointer(0)
    var captures=ArcPointer(0)
    var pair=pipeline(Optional(Owner(1,values))).flat_pair_with(Once(Owner(2,captures),True)).get()
    assert_equal(pair.value()[0].id,1)
    assert_equal(pair.value()[1].id,2)
    assert_equal(values[],0)
    assert_equal(captures[],0)
    _=pair^
    assert_equal(values[],1)
    assert_equal(captures[],1)
    assert_false(pipeline(Optional(Owner(3,values))).flat_tap(Once(Owner(4,captures),False)).get())
    assert_equal(values[],2)
    assert_equal(captures[],2)
    assert_false(pipeline(Optional[Owner]()).before(Factory(Owner(5,captures))).get())
    assert_equal(captures[],3)
    var next=pipeline(Optional(Owner(6,values))).followed_by(Factory(Owner(7,captures))).get()
    assert_equal(values[],3)
    assert_equal(next.value().id,7)
    _=next^
    assert_equal(captures[],4)
    comptime R=Reader[Int]
    def observe(value:Owner)->R.Pure[Int]:return R.pure(value.id)
    var delayed=pipeline[R](R.pure(Owner(8,values))).flat_tap(observe).get()
    assert_equal(values[],3)
    _=delayed^
    assert_equal(values[],4)
    var owned=run[R](pipeline[R](R.pure(Owner(9,values))).flat_tap(observe).get(),0)
    assert_equal(owned.id,9)
    assert_equal(values[],4)
    _=owned^
    assert_equal(values[],5)
    var errors=ArcPointer(0)
    def fail() raises Owner {errors}->List[Int]:raise Owner(10,errors)
    var pending=List[Owner]()
    pending.append(Owner(11,values));pending.append(Owner(12,values))
    var code=0
    try:_=pipeline(pending^).raising[Owner]().followed_by(fail).get()
    except error:
        comptime assert type_of(error)==Owner
        code=error.id
    assert_equal(code,10)
    assert_equal(values[],7)
    assert_equal(errors[],1)
    # Losing non-emptiness must retain exact ownership through the next map.
    def keep(owner: Owner) -> Bool: return owner.id > 1
    def consume(var owner: Owner) -> Int: return owner.id
    var rest = List[Owner]()
    rest.append(Owner(2,values))
    var filtered = pipeline[NonEmptyListFamily](NonEmptyList(Owner(1,values),rest^)).filter(keep)
    assert_equal(values[],8)
    assert_equal(filtered^.map(consume).get(),List[Int]([2]))
    assert_equal(values[],9)
