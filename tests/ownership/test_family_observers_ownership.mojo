"""Family observation moves payloads and releases callbacks, outputs, and errors once."""
from fp.callables import BorrowMutableCallable,BorrowOnceCallable
from fp.functions import pipeline
from fp.effects import ReaderT,run
from fp.algebra import ListFamily
from algebra_support.result_ownership import Token,trace
from std.testing import assert_equal
@fieldwise_init
struct Observe(BorrowMutableCallable):
    comptime Payload=Token
    comptime Result=Token
    comptime Failure=Token
    var capture:Token
    var fail:Bool
    def invoke_mut(mut self,ref value:Token) raises Token -> Token:
        self.capture.trace[].calls+=1
        if self.fail and value.id==2:raise Token(7,self.capture.trace)
        return Token(4,self.capture.trace)
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload=Token
    comptime Result=Token
    var capture:Token
    def invoke_once(deinit self,ref value:Token)->Token:
        self.capture.trace[].calls+=1
        return Token(4,self.capture.trace)

def eager[mode:Int](fail:Bool) raises:
    var state=trace()
    var input:List[Token]=[Token(1,state),Token(2,state),Token(3,state)]
    var error_id=0
    try:
        comptime if mode==0:_=pipeline(input^).pair_with(Observe(Token(6,state),fail)).get()
        elif mode==1:_=pipeline(input^).tap_each(Observe(Token(6,state),fail)).get()
        elif mode==2:_=pipeline(input^).pair_with(Observe(Token(6,state),fail)).get()
        else:_=pipeline(input^).tap_each(Observe(Token(6,state),fail)).get()
    except error:
        comptime assert type_of(error)==Token
        error_id=error.id
    assert_equal(error_id,7 if fail else 0)
    assert_equal(state[].calls,2 if fail else 3)
    for id in range(1,4):assert_equal(state[].drops[id],1)
    assert_equal(state[].drops[4],1 if fail else 3)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(fail))

def whole[piped_form:Bool]() raises:
    var state=trace()
    var value:Token
    comptime if piped_form:value=pipeline(Token(1,state)).tap(Once(Token(6,state))).get()
    else:value=pipeline(Token(1,state)).tap(Once(Token(6,state))).get()
    assert_equal(state[].calls,1)
    assert_equal(state[].drops[1],0)
    assert_equal(state[].drops[4],1)
    assert_equal(state[].drops[6],1)
    assert_equal(value.id,1)
    _=value^
    assert_equal(state[].drops[1],1)

def deferred(fail:Bool) raises:
    var state=trace()
    comptime Reader=ReaderT[ListFamily,Int]
    var abandoned=pipeline[Reader](Reader.pure(Token(1,state))).pair_with(Observe(Token(6,state),False)).get()
    _=abandoned^
    assert_equal(state[].calls,0)
    assert_equal(state[].drops[1],1)
    assert_equal(state[].drops[6],1)
    var pending=pipeline[Reader](Reader.pure(Token(2,state))).pair_with(Observe(Token(5,state),fail)).get()
    var result=List[Tuple[Token,Token]]()
    var raised=False
    try:result=run[Reader](pending^,0)
    except error:
        comptime assert type_of(error)==Token
        raised=True
    assert_equal(raised,fail)
    assert_equal(state[].calls,1)
    assert_equal(state[].drops[2],Int(fail))
    assert_equal(state[].drops[4],0)
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[7],Int(fail))
    if not fail:
        assert_equal(result[0][0].id,2)
        assert_equal(result[0][1].id,4)
    _=result^
    assert_equal(state[].drops[2],1)
    assert_equal(state[].drops[4],Int(not fail))
@fieldwise_init
struct View[o:ImmOrigin](BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Span[Int,Self.o]
    var view:Self.Result
    var calls:Int
    def invoke_mut(mut self,ref value:Int)->Self.Result:
        self.calls+=1
        return self.view[value:]
def external(owner:List[Int])->List[Tuple[Int,Span[Int,origin_of(owner)]]]:
    return pipeline[List[Int]]([0,1]).pair_with(View(Span(owner),0)).get()
def main() raises:
    for fail in range(2):
        comptime for mode in range(4):eager[mode](Bool(fail))
    whole[True]()
    whole[False]()
    deferred(False)
    deferred(True)
    var owner:List[Int]=[7,11]
    var views=external(owner)
    assert_equal(Pointer(to=views[1][1][0])==Pointer(to=owner[1]),True)
