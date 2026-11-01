"""Selected whole-outcome observation retains family timing and restoration."""
from fp.functions import pipeline
from fp.algebra import ResultFamily, ListFamily, IdentityFamily
from fp.algebra.contracts import AttemptTapContract
from fp.effects import Reader,ReaderT,ResultT,OptionalT,run
from fp.data import Result,Ok,Err
from fp.callables import BorrowCallable
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_family_ensure import Family

comptime Outcome=Result[Int,String]


def branches() raises:
    comptime I=ResultT[ListFamily,String]
    var seen=ArcPointer(List[String]())
    def observe(outcome:Outcome) {seen}->List[Result[NoneType,String]]:
        if outcome.is_ok():
            seen[].append(String(outcome._ok().value))
            if outcome._ok().value==0:return List[Result[NoneType,String]]()
        else:seen[].append(outcome._err().value)
        return [Result[NoneType,String](Ok(NoneType())),Result[NoneType,String](Err(String("observer"))),Result[NoneType,String](Ok(NoneType()))]
    var inputs=List[Outcome]([Outcome(Ok(4)),Outcome(Err(String("old"))),Outcome(Ok(0))])
    var pending=pipeline[I](inputs^).attempt_tap(observe)
    comptime assert type_of(pending).I==I
    var values=pending^.get()
    assert_equal(seen[],List[String](["4","old","0"]))
    assert_equal(len(values),6)
    assert_equal(values[0]._ok().value,4)
    assert_equal(values[1]._err().value,"observer")
    assert_equal(values[2]._ok().value,4)
    assert_equal(values[3]._err().value,"old")
    assert_equal(values[4]._err().value,"observer")
    assert_equal(values[5]._err().value,"old")
    comptime OptionalErrors=OptionalT[ResultFamily[String]]
    def absent(outcome:Outcome)->OptionalErrors.Pure[Int]:return Ok(Optional[Int]())
    var empty=pipeline[OptionalErrors](OptionalErrors.fail[Int](String("old"))).attempt_tap(absent).get()
    assert_equal(Bool(empty._ok().value),False)
    # A base failure outside the selected ResultT layer remains untouched.
    comptime Nested=ResultT[ResultFamily[String],String]
    var calls=0
    def nested(outcome:Outcome) {mut calls}->Nested.Pure[Int]:
        calls+=1
        return Nested.pure(0)
    var outer=Result[Outcome,String](Err(String("outer")))
    assert_equal(pipeline[Nested](outer^).attempt_tap(nested).get()._err().value,"outer")
    assert_equal(calls,0)


def deferred() raises:
    comptime R=Reader[Int]
    comptime I=ResultT[R,String]
    var calls=0
    def observe(outcome:Outcome) {mut calls}->I.Pure[String]:
        calls+=1
        return I.pure(String("discard"))
    var ok=pipeline[I](I.pure(5)).attempt_tap(observe)
    comptime assert type_of(ok).I==I
    def double(var value:Int)->Int:return value*2
    var continued=ok^.map(double).get()
    assert_equal(calls,0)
    assert_equal(run[R](continued^,0)._ok().value,10)
    assert_equal(calls,1)
    var failed=pipeline[I](I.fail[Int](String("original"))).attempt_tap(observe).get()
    assert_equal(calls,1)
    assert_equal(run[R](failed^,0)._err().value,"original")
    assert_equal(calls,2)
    var abandoned=pipeline[I](I.pure(9)).attempt_tap(observe).get()
    _ = abandoned^
    assert_equal(calls,2)
    def rejected(outcome:Outcome)->I.Pure[NoneType]:return I.fail[NoneType](String("replacement"))
    assert_equal(run[R](pipeline[I](I.fail[Int](String("original"))).attempt_tap(rejected).get(),0)._err().value,"replacement")
    def raised(outcome:Outcome) raises Int ->I.Pure[NoneType]:raise 751
    var native=pipeline[I](I.pure(6)).raising[Int]().attempt_tap(raised).get()
    var code=0
    try:_ = run[R](native^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,751)
    def stored(outcome:Outcome)->I.Pure[NoneType]:return I.pure(NoneType())
    var pointer:def(Outcome) thin ->I.Pure[NoneType]=stored
    var owned=pipeline[I](I.pure(7)).attempt_tap(pointer).get()
    pointer=rejected
    assert_equal(run[R](pointer(Outcome(Ok(0))),0)._err().value,"replacement")
    assert_equal(run[R](owned^,0)._ok().value,7)


def custom() raises:
    var calls=0
    def observed(outcome:Outcome) {mut calls}->Outcome:
        calls+=1
        return Ok(0)
    var kept=pipeline[Family[]](Outcome(Err(String("old")))).attempt_tap(observed)
    comptime assert type_of(kept).I==Family[]
    assert_equal(kept^.get()._err().value,"custom:old")
    assert_equal(calls,1)
    var code=0
    try:_ = pipeline[Family[True]](Outcome(Err(String("old")))).attempt_tap(observed).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,731)
    assert_equal(calls,2)
    # Observer failure skips restoration, including a fallible family.fail.
    def rejected(outcome:Outcome)->Outcome:return Err(String("observer"))
    var replacement:String
    try:
        var result=pipeline[Family[True]](Outcome(Err(String("old")))).attempt_tap(rejected).get()
        replacement=result._err().value
    except _:raise Error("observer failure must not restore the original")
    assert_equal(replacement,"observer")
    try:_ = pipeline[Family[False,True]](Outcome(Ok(1))).attempt_tap(observed).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,733)
    assert_equal(calls,2)
    # Intrinsic Result under a proven non-error family keeps its original API.
    var intrinsic=pipeline[IdentityFamily](Outcome(Err(String("original")))).attempt_tap(observed)
    comptime assert type_of(intrinsic).I==ResultFamily[String]
    assert_equal(intrinsic^.get()._err().value,"original")


def origins(owner:List[Int],other:List[Int]) raises:
    comptime View=type_of(Span(owner))
    comptime Other=type_of(Span(other))
    comptime R=Reader[Int]
    comptime I=ResultT[R,View]
    def observe(outcome:Result[View,View]) {ref other}->I.Pure[Other]:return I.pure(Span(other))
    var success=pipeline[I](I.pure(Span(owner))).attempt_tap(observe).get()
    assert_equal(run[R](success^,0)._ok().value.unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var failure=pipeline[I](I.fail[View](Span(owner))).attempt_tap(observe).get()
    assert_equal(run[R](failure^,0)._err().value.unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    def raised(outcome:Result[View,View]) raises Other {ref other}->I.Pure[NoneType]:raise Span(other)
    var pending=pipeline[I](I.pure(Span(owner))).raising[Other]().attempt_tap(raised).get()
    var same=False
    try:_ = run[R](pending^,0)
    except error:
        comptime assert type_of(error)==Other
        same=error.unsafe_ptr()==Span(other).unsafe_ptr()
    assert_equal(same,True)


def main() raises:
    branches()
    deferred()
    custom()
    origins(List[Int]([1,2]),List[Int]([3,4]))
