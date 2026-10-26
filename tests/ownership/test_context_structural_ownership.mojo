"""Structural methods move source owners and preserve deferred cleanup."""
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.effects import Reader,run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Owner(Movable):
    var id:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct Once(OnceUnary):
    var capture:Owner
    comptime Arg=Owner
    comptime Out=Owner
    def call_once(deinit self,var value:Owner)->Owner: return value^

def main() raises:
    var drops=ArcPointer(0)
    var values=List[Owner]()
    values.append(Owner(1,drops)); values.append(Owner(2,drops))
    var paired=pipeline(values^).tuple_left(String("x")).get()
    assert_equal(drops[],0); assert_equal(paired[1][1].id,2)
    _ = paired^
    assert_equal(drops[],2)
    drops[]=0
    var compacted=pipeline(Optional(Optional(Owner(3,drops)))).compact().get()
    assert_equal(compacted.value().id,3); assert_equal(drops[],0)
    _ = compacted^
    assert_equal(drops[],1)
    drops[]=0
    var flattened=pipeline(Optional(Optional(Owner(4,drops)))).flatten().get()
    _ = flattened^
    assert_equal(drops[],1)
    drops[]=0
    var applied=pipeline(Optional(Once(Owner(5,drops)))).ap(Optional(Owner(6,drops))).get()
    assert_equal(drops[],1); assert_equal(applied.value().id,6)
    _ = applied^
    assert_equal(drops[],2)
    drops[]=0
    _ = pipeline(Optional[Once]()).ap(Optional(Owner(7,drops))).get()
    assert_equal(drops[],1)
    drops[]=0
    _ = pipeline(Optional(Owner(8,drops))).void().get()
    assert_equal(drops[],1)
    drops[]=0
    comptime Deferred=Reader[Int]
    var pending=pipeline[Deferred](Deferred.pure(Owner(9,drops))).void().get()
    assert_equal(drops[],0)
    _ = run[Deferred](pending^,0)
    assert_equal(drops[],1)
