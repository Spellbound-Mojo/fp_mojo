"""Source admission retains move-only Array cleanup and short-circuit semantics."""
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily
from std.collections import Array
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct AdmissionOwner(Movable):
    var id:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self): self.drops[]+=1

def keep(var value:AdmissionOwner)->Optional[AdmissionOwner]: return Optional(value^)
def stop(var value:AdmissionOwner)->Optional[AdmissionOwner]:
    if value.id==2: return None
    return Optional(value^)
def main() raises:
    var drops=ArcPointer(0)
    var source:Array[AdmissionOwner,3]=[AdmissionOwner(1,drops),AdmissionOwner(2,drops),AdmissionOwner(3,drops)]
    var result=pipeline[ListFamily](source^).traverse[OptionalFamily](keep).get()
    assert_equal(len(result.value()),3)
    assert_equal(result.value()[2].id,3)
    assert_equal(drops[],0)
    _=result^
    assert_equal(drops[],3)
    var second:Array[AdmissionOwner,3]=[AdmissionOwner(1,drops),AdmissionOwner(2,drops),AdmissionOwner(3,drops)]
    var stopped=pipeline[ListFamily](second^).traverse[OptionalFamily](stop).get()
    assert_equal(Bool(stopped),False)
    assert_equal(drops[],6)
