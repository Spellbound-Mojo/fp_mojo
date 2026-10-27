"""Stored-error mapping respects the selected ResultT or OptionalT layer."""
from fp.algebra import ListFamily, ResultFamily, ErrorMapping, ApplicativeError
from fp.effects import ResultT, OptionalT, Reader, run
from fp.functions import pipeline
from fp.callables import MutableUnary
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.external import PublicMonad
from context_layer_error_mapping_support import MappingMonad, TypedList
from context_error_mapping_nonmonad_support import ToValidation


@fieldwise_init
struct Numbered(MutableUnary):
    var count:Int
    comptime Arg=String
    comptime Out=Int
    def call_mut(mut self,var error:String)->Int:
        self.count+=1
        return self.count


def ordered() raises:
    comptime I = ResultT[ListFamily,String]
    comptime assert not conforms_to(ListFamily,ErrorMapping)
    comptime R = Result[Int,String]
    var trace = ArcPointer(List[String]())
    def show(var value: Int) {trace} -> String:
        trace[].append("ok:" + String(value))
        return String(value)
    def size(var error: String) {trace} -> Int:
        trace[].append("err:" + error)
        return error.byte_length()
    var source = List[R]([R(Err(String("a"))), R(Ok(2)), R(Err(String("ccc")))])
    var selected = pipeline[I](source^).map_both(show,size)
    comptime assert type_of(selected).I == ResultT[ListFamily,Int]
    var mapped = selected^.get()
    assert_equal(trace[],List[String](["err:a","ok:2","err:ccc"]))
    assert_equal(mapped[0]._err().value,1)
    assert_equal(mapped[1]._ok().value,"2")
    assert_equal(mapped[2]._err().value,3)
    trace[].clear()
    def stop(var value: Int) raises Int {trace} -> String:
        trace[].append("ok:" + String(value))
        raise 767
    var interrupted = List[R]([R(Err(String("a"))), R(Ok(2)), R(Err(String("ccc")))])
    var code = 0
    try: _ = pipeline[I](interrupted^).raising[Int]().map_both(stop,size).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,767)
    assert_equal(trace[],List[String](["err:a","ok:2"]))
    var count = 0
    def numbered(var error: String) {mut count} -> Int:
        count += 1
        return count
    var repeated = List[R]([R(Err(String("first"))),R(Ok(5)),R(Err(String("second")))])
    var numbered_result = pipeline[I](repeated^).map_err(numbered).get()
    assert_equal(count,2)
    assert_equal(numbered_result[0]._err().value,1)
    assert_equal(numbered_result[1]._ok().value,5)
    assert_equal(numbered_result[2]._err().value,2)
    var owned_state=List[R]([R(Err(String("first"))),R(Ok(5)),R(Err(String("second")))])
    var numbered_owned=pipeline[I](owned_state^).map_err(Numbered(0)).get()
    assert_equal(numbered_owned[0]._err().value,1)
    assert_equal(numbered_owned[2]._err().value,2)


def nested() raises:
    comptime Base = ResultFamily[String]
    comptime I = ResultT[Base,Int]
    comptime Inner = Result[Int,Int]
    comptime Source = Result[Inner,String]
    var calls = ArcPointer(0)
    def show(var value: Int) {calls} -> String:
        calls[] += 1
        return String(value)
    def explain(var error: Int) {calls} -> String:
        calls[] += 10
        return "inner:" + String(error)
    var outer = pipeline[I](Source(Err(String("outer")))).map_both(show,explain)
    comptime assert type_of(outer).I == ResultT[Base,String]
    assert_equal(outer^.get()._err().value,"outer")
    assert_equal(calls[],0)
    var inner = Source(Ok(Inner(Err(7))))
    var selected = pipeline[I](inner^).map_both[Target=ResultT[Base,String]](show,explain).get()
    comptime assert type_of(selected) == Result[Result[String,String],String]
    assert_equal(selected._ok().value._err().value,"inner:7")
    assert_equal(calls[],10)


def optional() raises:
    comptime I = OptionalT[ResultFamily[String]]
    comptime Target = OptionalT[ResultFamily[Int]]
    comptime Source = Result[Optional[Int],String]
    var calls = ArcPointer(0)
    def show(var value: Int) {calls} -> String:
        calls[] += 1
        return String(value)
    def size(var error: String) {calls} -> Int:
        calls[] += 10
        return error.byte_length()
    var absent = pipeline[I](Source(Ok(Optional[Int]()))).map_both(show,size)
    comptime assert type_of(absent).I == Target
    assert_equal(Bool(absent^.get()._ok().value),False)
    assert_equal(calls[],0)
    var present = pipeline[I](Source(Ok(Optional(3)))).map_both[Target=Target](show,size)
    def length(var text: String) -> Int: return text.byte_length()
    assert_equal(present^.map(length).get()._ok().value.value(),1)
    assert_equal(calls[],1)
    assert_equal(pipeline[I](Source(Err(String("four")))).map_both(show,size).get()._err().value,4)
    assert_equal(calls[],11)
    assert_equal(Bool(pipeline[I](Source(Ok(Optional[Int]()))).map_err(size).get()._ok().value),False)
    assert_equal(calls[],11)
    # Compose both newly supported layers: absence stays local to OptionalT.
    comptime Stacked=OptionalT[ResultT[ListFamily,String]]
    var sources=List[Source]([Source(Err(String("a"))),Source(Ok(Optional[Int]())),Source(Ok(Optional(2))),Source(Err(String("ccc")))])
    var stacked=pipeline[Stacked](sources^).map_both(show,size)
    comptime assert type_of(stacked).I==OptionalT[ResultT[ListFamily,Int]]
    var values=stacked^.get()
    assert_equal(values[0]._err().value,1)
    assert_equal(Bool(values[1]._ok().value),False)
    assert_equal(values[2]._ok().value.value(),"2")
    assert_equal(values[3]._err().value,3)
    assert_equal(calls[],32)


def mapping_only() raises:
    comptime Base = MappingMonad[String]
    comptime I = OptionalT[Base]
    comptime assert not conforms_to(Base,ApplicativeError)
    comptime assert not conforms_to(I,ApplicativeError)
    def size(var error:String)->Int:return error.byte_length()
    var direct = pipeline[Base](Result[Int,String](Err(String("guarded")))).map_err[Target=MappingMonad[Int]](size)
    assert_equal(direct^.get()._err().value,7)
    var selected = pipeline[I](Result[Optional[Int],String](Err(String("only")))).map_err(size)
    comptime assert type_of(selected).I == OptionalT[MappingMonad[Int]]
    assert_equal(selected^.get()._err().value,4)
    var absent = pipeline[I](Result[Optional[Int],String](Ok(Optional[Int]()))).map_err(size).get()
    assert_equal(Bool(absent._ok().value),False)
    # A non-Monad default is rejected, but a permitted explicit Monad works.
    def tag(var error:String)->String:return "mapped:"+error
    comptime Explicit=OptionalT[ResultFamily[String]]
    var overridden=pipeline[OptionalT[ToValidation]](Result[Optional[Int],String](Err(String("old")))).map_err[Target=Explicit](tag)
    comptime assert type_of(overridden).I==Explicit
    assert_equal(overridden^.get()._err().value,"mapped:old")


def deferred() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var calls = ArcPointer(0)
    def show(var value: Int) {calls} -> String:
        calls[] += 1
        return String(value)
    def size(var error: String) {calls} -> Int:
        calls[] += 10
        return error.byte_length()
    var pending = pipeline[I](I.fail[Int](String("later"))).map_both(show,size).get()
    assert_equal(calls[],0)
    assert_equal(run[R](pending^,0)._err().value,5)
    assert_equal(calls[],10)
    var abandoned = pipeline[I](I.pure(1)).map_both(show,size).get()
    _ = abandoned^
    assert_equal(calls[],10)
    def raised(var value: Int) raises Int {calls} -> String:
        calls[] += 1
        raise 768
    var failing = pipeline[I](I.pure(1)).raising[Int]().map_both(raised,size).get()
    assert_equal(calls[],10)
    var code = 0
    try: _ = run[R](failing^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,768)
    assert_equal(calls[],11)
    # A base map construction failure occurs before either callback runs.
    comptime Construct = ResultT[PublicMonad[R,1],String]
    try: _ = pipeline[Construct](Construct.pure(1)).map_both(show,size).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,702)
    assert_equal(calls[],11)


def rebound() raises:
    comptime Base = TypedList[Result[Int,String]]
    comptime I = ResultT[Base,String]
    def show(var value:Int)->String:return String(value)
    def size(var error:String)->Int:return error.byte_length()
    var selected=pipeline[I](I.pure(5)).map_both(show,size)
    comptime assert type_of(selected).I == ResultT[TypedList[Result[String,Int]],Int]
    assert_equal(selected^.map(size).get()[0]._ok().value,1)
    def tag(var error:String)->String:return "mapped:"+error
    var same=pipeline[I](I.fail[Int](String("old"))).map_err(tag)
    comptime assert type_of(same).I==I
    assert_equal(same^.get()[0]._err().value,"mapped:old")


def origins(left:List[Int],right:List[Int]) raises:
    comptime L = type_of(Span(left))
    comptime R = type_of(Span(right))
    comptime I = ResultT[Reader[Int],L]
    def keep(var value:L)->L:return value
    def replace(var error:L) {ref right}->R:return Span(right)
    var changed = pipeline[I](I.fail[L](Span(left))).map_both(keep,replace)
    comptime assert type_of(changed).I == ResultT[Reader[Int],R]
    var value = run[Reader[Int]](changed^.get(),0)
    assert_equal(value._err().value.unsafe_ptr()==Span(right).unsafe_ptr(),True)
    def raised(var error:L) raises R {ref right}->Int:raise Span(right)
    var pending = pipeline[I](I.fail[L](Span(left))).raising[R]().map_err(raised).get()
    var same = False
    try: _ = run[Reader[Int]](pending^,0)
    except error:
        comptime assert type_of(error)==R
        same=error.unsafe_ptr()==Span(right).unsafe_ptr()
    assert_equal(same,True)


def main() raises:
    ordered()
    nested()
    optional()
    mapping_only()
    deferred()
    rebound()
    origins(List[Int]([1]),List[Int]([2]))
