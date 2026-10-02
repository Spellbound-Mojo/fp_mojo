"""Shared external Box traversal checks; this entry runs Reader and State."""
from fp.algebra import traverse, ListFamily, StringMonoid
from fp.effects import ReaderT, StateT, OptionalT, ResultT, WriterT, action, run, writer, run_writer
from fp.callables import OnceUnary, BorrowOnceCallable, as_unary
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.testing import assert_equal
from algebra_support.box import Box, BoxMonad
from algebra_support.iterators import Counted

comptime R=ReaderT[BoxMonad,Int]
comptime S=StateT[BoxMonad,Int]
comptime W=WriterT[BoxMonad,StringMonoid]

@fieldwise_init
struct ReadBox(BorrowOnceCallable):
    var item:Int
    comptime Payload=Int
    comptime Result=Box[Int]
    def invoke_once(deinit self,ref environment:Int) raises Never capturing ->Box[Int]:
        return Box(self.item+environment)

@fieldwise_init
struct StateBox(OnceUnary):
    var item:Int
    comptime Arg=Int
    comptime Out=Box[Tuple[Int,Int]]
    def call_once(deinit self,var state:Int)->Box[Tuple[Int,Int]]:
        var updated=state+self.item
        return Box(Tuple(updated,updated))

def read_box(var item:Int)->type_of(action[R,Int](ReadBox(0))):
    return action[R,Int](ReadBox(item))

def state_box(var item:Int)->type_of(action[S,Int](StateBox(0))):
    return action[S,Int](StateBox(item))

def optional_box(var item:Int)->Box[Optional[Int]]:
    return Box(Optional[Int]() if item==3 else Optional(item))

def result_box(var item:Int)->Box[Result[Int,Int]]:
    if item==3:
        return Box(Result[Int,Int](Err(37)))
    return Box(Result[Int,Int](Ok(item)))

def writer_box(var item:Int)->type_of(writer[W,Int](Box(Tuple(String(),0)))):
    return writer[W,Int](Box(Tuple(String(item),item)))

def check[kind:Int]() raises:
    for count in [0,2,5]:
        var values=List[Int]()
        var reads=List[Int]()
        var states=List[Int]()
        var state=10
        var log=String()
        for item in range(1,count+1):
            values.append(item)
            reads.append(item+10)
            state+=item
            states.append(state)
            log+=String(item)
        var pulls=0
        comptime if kind==0:
            var reader=traverse[ListFamily,R](as_unary(read_box),Counted(Pointer(to=pulls),0,count))
            assert_equal(pulls,0)
            var environment=10
            var read_output=run[R](reader^,environment)
            comptime assert type_of(read_output)==Box[List[Int]]
            assert_equal(read_output.value,reads)
            assert_equal(pulls,count+1)
        elif kind==1:
            var computation=traverse[ListFamily,S](as_unary(state_box),Counted(Pointer(to=pulls),0,count))
            assert_equal(pulls,0)
            var state_output=run[S](computation^,10)
            comptime assert type_of(state_output)==Box[Tuple[List[Int],Int]]
            assert_equal(state_output.value[0],states)
            assert_equal(state_output.value[1],state)
            assert_equal(pulls,count+1)
        elif kind==2:
            var optional=traverse[ListFamily,OptionalT[BoxMonad]](as_unary(optional_box),Counted(Pointer(to=pulls),0,count))
            comptime assert type_of(optional)==Box[Optional[List[Int]]]
            assert_equal(Bool(optional.value),count!=5)
            if optional.value:
                assert_equal(optional.value.value(),values)
            assert_equal(pulls,3 if count==5 else count+1)
        elif kind==3:
            var result=traverse[ListFamily,ResultT[BoxMonad,Int]](as_unary(result_box),Counted(Pointer(to=pulls),0,count))
            comptime assert type_of(result)==Box[Result[List[Int],Int]]
            assert_equal(result.value.is_err(),count==5)
            var stored=0
            var result_values=Optional[List[Int]]()
            try:
                result_values=Optional(result^.unwrap().raise_on_err())
            except error:
                stored=error
            if result_values:
                assert_equal(result_values.value(),values)
            assert_equal(stored,37 if count==5 else 0)
            assert_equal(pulls,3 if count==5 else count+1)
        elif kind==4:
            var written=run_writer[W](traverse[ListFamily,W](as_unary(writer_box),Counted(Pointer(to=pulls),0,count)))
            comptime assert type_of(written)==Box[Tuple[String,List[Int]]]
            assert_equal(written.value[0],log)
            assert_equal(written.value[1],values)
            assert_equal(pulls,count+1)


def main() raises:
    check[0]()
    check[1]()
    print("external base traversal: Reader and State")
