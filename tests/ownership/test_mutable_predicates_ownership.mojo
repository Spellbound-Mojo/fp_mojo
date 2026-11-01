"""Predicates borrow move-only payloads and release state and suffix exactly once."""
from fp.callables import BorrowMutableCallable, invoke_borrowed_repeated
from fp.iteration import iterated
from algebra_support.result_ownership import Token,trace
from std.iter import Iterator,next
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element=Token
    var values:List[Token]
    var owner:Token
    def __next__(mut self) raises StopIteration -> Token:
        self.owner.trace[].pulls+=1
        if not self.values:raise StopIteration()
        return self.values.pop()

@fieldwise_init
struct EveryOther(BorrowMutableCallable):
    comptime Payload=Token
    comptime Result=Bool
    var capture:Token
    var calls:Int
    def invoke_mut(mut self,ref payload:Token)->Bool:
        self.calls+=1
        self.capture.trace[].calls+=1
        return self.calls%2==0 and payload.id==self.calls

@fieldwise_init
struct Match(BorrowMutableCallable):
    comptime Payload=Token
    comptime Result=Bool
    comptime Failure=Token
    var capture:Token
    var fail:Bool
    var inverted:Bool
    def invoke_mut(mut self,ref payload:Token) raises Token -> Bool:
        self.capture.trace[].calls+=1
        if self.fail and payload.id==2:raise Token(7,self.capture.trace)
        return (payload.id==2)!=self.inverted

def lazy() raises:
    var state=trace()
    var source=Source([Token(3,state),Token(2,state),Token(1,state)],Token(5,state))
    var pending=iterated(source^).filter(EveryOther(Token(6,state),0))
    assert_equal(state[].pulls,0)
    var retained=next(pending)
    assert_equal(retained.id,2)
    assert_equal(state[].calls,2)
    assert_equal(state[].drops[1],1)
    assert_equal(state[].drops[2],0)
    assert_equal(state[].drops[3],0)
    _=pending^
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[3],1)
    assert_equal(retained.id,2)
    _=retained^
    assert_equal(state[].drops[2],1)

def terminal[mode:Int](fail:Bool) raises:
    var state=trace()
    var source=Source([Token(3,state),Token(2,state),Token(1,state)],Token(5,state))
    var predicate=Match(Token(6,state),fail,mode==2)
    var retained=Optional[Token]()
    var observed=0
    var accepted=False
    var count=0
    try:
        comptime if mode==0:retained=iterated(source^).find(predicate^)
        elif mode==1:
            accepted=iterated(source^).any(predicate^)
        elif mode==2:
            accepted=iterated(source^).all(predicate^)
        else:
            count=iterated(source^).count_where(predicate^)
    except error:
        comptime assert type_of(error)==Token
        observed=error.id
    if not fail:
        comptime if mode==1 or mode==2: assert_equal(accepted,mode==1)
        elif mode==3: assert_equal(count,1)
    assert_equal(observed,7 if fail else 0)
    assert_equal(state[].calls,3 if mode==3 and not fail else 2)
    assert_equal(state[].pulls,4 if mode==3 and not fail else 2)
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(fail))
    assert_equal(state[].drops[1],1)
    assert_equal(state[].drops[2],0 if mode==0 and not fail else 1)
    assert_equal(state[].drops[3],1)
    _=retained^
    assert_equal(state[].drops[2],1)

@fieldwise_init
struct View[o:ImmOrigin](BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Span[Int,Self.o]
    var view:Self.Result
    var calls:Int
    def invoke_mut(mut self,ref item:Int)->Self.Result:
        self.calls+=1
        return self.view[item:]

def external(owner:List[Int])->Span[Int,origin_of(owner)]:
    var callback=View(Span(owner),0)
    var offset=1
    return invoke_borrowed_repeated[Never](offset,callback)

def main() raises:
    lazy()
    for fail in range(2):
        comptime for mode in range(4):terminal[mode](Bool(fail))
    var owner:List[Int]=[7,11]
    var view=external(owner)
    assert_equal(Pointer(to=view[0])==Pointer(to=owner[1]),True)
