"""Projection state, payloads, outputs, and errors retain exact ownership and origins."""
from fp.callables import BorrowMutableCallable
from fp.iteration import iterated,min_by,max_by,minimum_by_non_empty,maximum_by_non_empty
from fp.data import NonEmptyList
from algebra_support.result_ownership import Token,trace
from std.iter import next
from std.testing import assert_equal
@fieldwise_init
struct Rank(BorrowMutableCallable):
    comptime Payload=Token
    comptime Result=Int
    comptime Failure=Token
    var capture:Token
    var fail:Bool
    def invoke_mut(mut self,ref value:Token) raises Token -> Int:
        self.capture.trace[].calls+=1
        if self.fail and value.id==2:raise Token(7,self.capture.trace)
        return value.id
@fieldwise_init
struct Observe(BorrowMutableCallable):
    comptime Payload=Token
    comptime Result=Token
    var capture:Token
    def invoke_mut(mut self,ref value:Token)->Token:
        self.capture.trace[].calls+=1
        return Token(4,self.capture.trace)

def extrema[mode:Int](fail:Bool) raises:
    var state=trace()
    var result=Optional[Token]()
    var error_id=0
    try:
        comptime if mode==0:result=min_by([Token(1,state),Token(2,state),Token(3,state)],Rank(Token(6,state),fail))
        elif mode==1:result=max_by([Token(1,state),Token(2,state),Token(3,state)],Rank(Token(6,state),fail))
        elif mode==2:result=minimum_by_non_empty(NonEmptyList(Token(1,state),[Token(2,state),Token(3,state)]),Rank(Token(6,state),fail))
        else:result=maximum_by_non_empty(NonEmptyList(Token(1,state),[Token(2,state),Token(3,state)]),Rank(Token(6,state),fail))
    except error:
        comptime assert type_of(error)==Token
        error_id=error.id
    assert_equal(error_id,7 if fail else 0)
    assert_equal(state[].calls,2 if fail else 3)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(fail))
    var kept=0 if fail else 1 if mode%2==0 else 3
    for id in range(1,4):assert_equal(state[].drops[id],Int(id!=kept))
    if not fail:assert_equal(result.value().id,kept)
    _=result^
    for id in range(1,4):assert_equal(state[].drops[id],1)

def lazy[paired:Bool]() raises:
    var state=trace()
    var source:List[Token]=[Token(1,state),Token(2,state),Token(3,state)]
    comptime if paired:
        var pending=iterated(source^).pair_with(Observe(Token(6,state)))
        assert_equal(state[].calls,0)
        var value=next(pending)
        assert_equal(state[].calls,1)
        assert_equal(state[].drops[1],0)
        assert_equal(state[].drops[4],0)
        _=pending^
        assert_equal(state[].drops[2],1)
        assert_equal(state[].drops[3],1)
        assert_equal(state[].drops[6],1)
        assert_equal(value[0].id,1)
        assert_equal(value[1].id,4)
        _=value^
        assert_equal(state[].drops[1],1)
        assert_equal(state[].drops[4],1)
    else:
        var pending=iterated(source^).tap_each(Observe(Token(6,state)))
        var value=next(pending)
        assert_equal(state[].calls,1)
        assert_equal(state[].drops[4],1)
        _=pending^
        assert_equal(state[].drops[2],1)
        assert_equal(state[].drops[3],1)
        assert_equal(state[].drops[6],1)
        assert_equal(value.id,1)
        _=value^
        assert_equal(state[].drops[1],1)
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
    return iterated(range(2)).pair_with(View(Span(owner),0)).to_list()
def main() raises:
    for fail in range(2):
        comptime for mode in range(4):extrema[mode](Bool(fail))
    lazy[True]()
    lazy[False]()
    var owner:List[Int]=[7,11]
    var views=external(owner)
    assert_equal(Pointer(to=views[1][1][0])==Pointer(to=owner[1]),True)
