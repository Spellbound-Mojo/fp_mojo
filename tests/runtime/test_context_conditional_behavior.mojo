"""Selected conditionals preserve branch choice, absence and native errors."""
from fp.functions import pipeline,Identity
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from std.testing import assert_equal
from std.memory import ArcPointer

def yes() -> Optional[Int]: return Optional(1)
def no() -> Optional[Int]: return Optional(2)
def yes_never() raises Never -> Optional[Int]: return Optional(3)
def fails() raises Int -> Optional[Int]: raise 7

def main() raises:
    assert_equal(pipeline(Optional(True)).if_effect(yes,no).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(yes,no).get().value(),2)
    assert_equal(Bool(pipeline(Optional[Bool]()).if_effect(yes,no).get()),False)
    var left: def() thin -> Optional[Int]=yes
    var right: def() raises Never thin -> Optional[Int]=yes_never
    assert_equal(pipeline(Optional(False)).if_effect(left,right).get().value(),3)
    var failure: def() raises Int thin -> Optional[Int]=fails
    var code=0
    try: _ = pipeline(Optional(True)).raising[Int]().if_effect(failure,right).get()
    except error: code=error
    assert_equal(code,7)
    comptime Deferred=Reader[Int]
    def first() -> Deferred.Pure[Int]: return Deferred.pure(4)
    def second() -> Deferred.Mapped[Deferred.Pure[Int],Identity[Int]]:
        return Deferred.map(Identity[Int](),Deferred.pure(5))
    var pending=pipeline[Deferred](Deferred.pure(True)).if_effect(first,second).get()
    assert_equal(run[Deferred](pending^,0),4)
    var other=pipeline[Deferred](Deferred.pure(False)).if_effect(first,second).get()
    assert_equal(run[Deferred](other^,0),5)
    var calls=ArcPointer(0)
    def result_left() {calls} -> Result[Int,String]:
        calls[] += 1
        return Ok(1)
    def result_right() {calls} -> Result[Int,String]:
        calls[] += 10
        return Err(String("branch"))
    var skipped=pipeline(Result[Bool,String](Err(String("source")))).if_effect(result_left,result_right).get()
    assert_equal(skipped._err().value,"source"); assert_equal(calls[],0)
    var rejected=pipeline(Result[Bool,String](Ok(False))).if_effect(result_left,result_right).get()
    assert_equal(rejected._err().value,"branch"); assert_equal(calls[],10)
    assert_equal(pipeline(Result[Bool,String](Ok(True))).if_effect(result_left,result_right).get()._ok().value,1)
    assert_equal(calls[],11)
