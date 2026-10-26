from fp.functions import pipeline
from fp.algebra import ListFamily,OptionalFamily,NonEmptyListFamily
from fp.data import NonEmptyList,Result,Ok,Err
from std.collections import Array
from std.testing import assert_equal

def present(var value:Int)->Optional[Int]: return Optional(value+1)
def inspect(value:Int)->Optional[Bool]: return Optional(value>1)
def select(var value:Int)->Optional[Optional[Int]]:
    if value>1: return Optional(Optional(value))
    return Optional(Optional[Int]())
def validate(var value:Int)->Result[Int,List[String]]:
    if value<0: return Err(List[String]([String(value)]))
    return Ok(value)
def branches(var value:Int)->List[Int]: return List[Int]([value,-value])
def main() raises:
    assert_equal(pipeline(Optional(1)).flat_map(present).get().value(),2)
    assert_equal(pipeline(List[Int]([1,2])).flat_map(branches).get(),List[Int]([1,-1,2,-2]))
    var array:Array[Int,3]=[1,2,3]
    assert_equal(pipeline[ListFamily](array^).traverse[OptionalFamily](present).get().value(),List[Int]([2,3,4]))
    var cursor=iter(List[Int]([1,2,3]))
    try: _=cursor.__next__()
    except: raise Error("missing first item")
    assert_equal(pipeline[ListFamily](cursor^).traverse[OptionalFamily](present).get().value(),List[Int]([3,4]))
    var gathered=pipeline[NonEmptyListFamily](NonEmptyList(1,List[Int]([2]))).traverse[OptionalFamily](present).get()
    assert_equal(gathered.unsafe_take().into_list(),List[Int]([2,3]))

    var observed:Array[Int,2]=[1,2]
    assert_equal(pipeline[ListFamily](observed^).traverse_tap[OptionalFamily](inspect).get().value(),List[Int]([1,2]))
    var filtered:Array[Int,2]=[1,2]
    assert_equal(pipeline[ListFamily](filtered^).filter_effect[OptionalFamily](inspect).get().value(),List[Int]([2]))
    var selected:Array[Int,2]=[1,2]
    assert_equal(pipeline[ListFamily](selected^).traverse_filter[OptionalFamily](select).get().value(),List[Int]([2]))
    var options:Array[Optional[Int],2]=[Optional(1),Optional(2)]
    assert_equal(pipeline[ListFamily](options^).sequence[OptionalFamily]().get().value(),List[Int]([1,2]))
    var invalid:Array[Int,2]=[-1,-2]
    assert_equal(pipeline[ListFamily](invalid^).par_traverse(validate).get()._err().value,List[String](["-1","-2"]))
    var results:Array[Result[Int,List[String]],2]=[Result[Int,List[String]](Ok(1)),Result[Int,List[String]](Ok(2))]
    assert_equal(pipeline[ListFamily](results^).par_sequence().get()._ok().value,List[Int]([1,2]))
