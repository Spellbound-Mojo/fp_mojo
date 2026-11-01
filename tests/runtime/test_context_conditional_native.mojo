"""Factories preserve closure, callable and thin-pointer storage at both native result ABIs."""
from fp.functions import pipeline
from fp.callables import Thunk
from fp.effects import Reader,run
from fp.data import Result,Ok
from std.testing import assert_equal

@fieldwise_init
struct Factory[T:Copyable & Deinitable](Thunk):
    var value:Self.T
    comptime Out=Optional[Self.T]
    def call(self)->Self.Out: return Optional(self.value.copy())
def number()->Optional[Int]: return Optional(1)
def text()->Optional[String]: return Optional(String("x"))
def result()->Result[Int,String]: return Ok(3)
comptime Deferred=Reader[Int]
def later()->Deferred.Pure[Int]: return Deferred.pure(7)
def changed()->Deferred.Pure[Int]: return Deferred.pure(9)
def main() raises:
    var register:def() thin -> Optional[Int]=number
    var memory:def() thin -> Optional[String]=text
    var pending=pipeline[Deferred](Deferred.pure(True)).if_effect(later,later).get()
    assert_equal(run[Deferred](pending^,0),7)
    var pointer:def() thin -> Deferred.Pure[Int]=later
    var owned=pipeline[Deferred](Deferred.pure(True)).if_effect(pointer,pointer).get()
    pointer=changed
    var moved=pointer
    _ = moved()
    assert_equal(run[Deferred](owned^,0),7)
    var capture=String("x")
    def captured() {capture}->Optional[String]: return Optional(capture)
    var value=1
    def captured_number() {value}->Optional[Int]: return Optional(value)
    assert_equal(pipeline(Optional(True)).if_effect(number,number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(number,number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(number,register).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(number,register).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(number,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(number,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(number,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(number,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(register,number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(register,number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(register,register).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(register,register).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(register,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(register,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(register,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(register,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(Factory(1),number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(Factory(1),number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(Factory(1),register).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(Factory(1),register).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(Factory(1),Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(Factory(1),Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(Factory(1),captured_number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(Factory(1),captured_number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(captured_number,number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(captured_number,number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(captured_number,register).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(captured_number,register).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(captured_number,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(captured_number,Factory(1)).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(captured_number,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(False)).if_effect(captured_number,captured_number).get().value(),1)
    assert_equal(pipeline(Optional(True)).if_effect(text,text).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(text,text).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(text,memory).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(text,memory).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(text,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(text,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(text,captured).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(text,captured).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(memory,text).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(memory,text).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(memory,memory).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(memory,memory).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(memory,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(memory,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(memory,captured).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(memory,captured).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(Factory(String("x")),text).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(Factory(String("x")),text).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(Factory(String("x")),memory).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(Factory(String("x")),memory).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(Factory(String("x")),Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(Factory(String("x")),Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(Factory(String("x")),captured).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(Factory(String("x")),captured).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(captured,text).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(captured,text).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(captured,memory).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(captured,memory).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(captured,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(captured,Factory(String("x"))).get().value(),"x")
    assert_equal(pipeline(Optional(True)).if_effect(captured,captured).get().value(),"x")
    assert_equal(pipeline(Optional(False)).if_effect(captured,captured).get().value(),"x")
    # Existing Result factory methods now own their exact thin pointers too.
    var raw:def() thin -> Result[Int,String]=result
    _ = pipeline(Result[Int,String](Ok(1))).before(raw).get()
