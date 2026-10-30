"""Effectful searches retain unique owners; mapped monoidal folds move values."""
from fp.iteration import iterated, find_effect, find_map_effect, fold_map_effect, sequence_filter
from fp.algebra import OptionalFamily, ResultFamily, ListMonoid
from fp.data import Result, Ok, Err
from fp.callables import MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct I6Owner(Movable):
    var text:String
    var drops:ArcPointer[Int]
    def __deinit__(deinit self): self.drops[]+=1

@fieldwise_init
struct I6OwnedMapper(MutableUnary):
    comptime Arg=I6Owner
    comptime Out=Result[Optional[I6Owner],String]
    var capture:I6Owner
    var calls:ArcPointer[Int]
    def call_mut(mut self,var item:Self.Arg)->Self.Out:
        self.calls[]+=1
        if item.text=="fail":return Err(String("stored failure"))
        if item.text==self.capture.text:return Ok(Optional(item^))
        return Ok(Optional[I6Owner]())

def i6_keep(value:I6Owner)->Optional[Bool]:return Optional(value.text=="keep")
def i6_list(var value:I6Owner)->Result[List[I6Owner],String]:
    if value.text=="fail":return Err(String("stored failure"))
    var values=List[I6Owner]()
    values.append(value^)
    return Ok(values^)

def i6_owned_source(drops:ArcPointer[Int],failure:Bool=False)->List[I6Owner]:
    var values=List[I6Owner]()
    values.append(I6Owner("first",drops))
    values.append(I6Owner("fail" if failure else "keep",drops))
    values.append(I6Owner("unvisited",drops))
    return values^

def main() raises:
    var drops=ArcPointer(0)
    var selected=find_effect[OptionalFamily](i6_owned_source(drops),i6_keep)
    var found=selected.take()
    var value=found.take()
    assert_equal(value.text,"keep")
    assert_equal(drops[],2)
    _=value^
    assert_equal(drops[],3)
    drops[]=0
    var calls=ArcPointer(0)
    var mapped=find_map_effect[ResultFamily[String]](i6_owned_source(drops),I6OwnedMapper(I6Owner("keep",drops),calls)).raise_on_err()
    var moved=mapped.take()
    assert_equal(moved.text,"keep")
    assert_equal(calls[],2);assert_equal(drops[],3)
    _=moved^
    assert_equal(drops[],4)
    drops[]=0;calls[]=0
    var failed=iterated(i6_owned_source(drops,True)).find_map_effect[ResultFamily[String]](I6OwnedMapper(I6Owner("keep",drops),calls))
    assert_true(failed.is_err());assert_equal(calls[],2);assert_equal(drops[],4)
    drops[]=0
    var combined=fold_map_effect[ResultFamily[String],ListMonoid[I6Owner]](i6_owned_source(drops),i6_list).raise_on_err()
    assert_equal(combined[0].text,"first");assert_equal(combined[1].text,"keep");assert_equal(combined[2].text,"unvisited")
    assert_equal(drops[],0)
    _=combined^
    assert_equal(drops[],3)
    drops[]=0
    var failure=fold_map_effect[ResultFamily[String],ListMonoid[I6Owner]](i6_owned_source(drops,True),i6_list)
    assert_true(failure.is_err());assert_equal(drops[],3)
    drops[]=0
    var effects=List[Result[Optional[I6Owner],String]]()
    effects.append(Ok(Optional(I6Owner("retained heap contents",drops))))
    effects.append(Ok(Optional[I6Owner]()))
    var sequenced=sequence_filter[ResultFamily[String]](effects^).raise_on_err()
    assert_equal(sequenced[0].text,"retained heap contents")
    assert_equal(drops[],0)
    _=sequenced^
    assert_equal(drops[],1)
