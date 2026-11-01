"""Owned fold steps preserve drop-once cleanup, errors, breaks and external origins."""
from fp.callables import MutableBinary
from fp.iteration import fold_left, fold_until, reduce, reduce_optional, iterated, EmptyReductionError, ReductionStepError
from fp.data import ControlFlow, Break, Continue
from algebra_support.result_ownership import Token, trace
from std.iter import Iterator
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element=Token
    var remaining:List[Token]
    var owner:Token
    def __next__(mut self) raises StopIteration -> Token:
        self.owner.trace[].pulls+=1
        if not self.remaining: raise StopIteration()
        return self.remaining.pop()

@fieldwise_init
struct Step(MutableBinary):
    comptime First=Token
    comptime Second=Token
    comptime Out=Token
    comptime Error=Token
    var capture:Token
    var fail:Bool
    def call_mut(mut self,var carry:Token,var item:Token) raises Token -> Token:
        self.capture.trace[].calls+=1
        if self.fail and item.id==2: raise Token(7,self.capture.trace)
        return carry^

@fieldwise_init
struct Until(MutableBinary):
    comptime First=Token
    comptime Second=Token
    comptime Out=ControlFlow[Token,Token]
    comptime Error=Token
    var step:Step
    def call_mut(mut self,var carry:Token,var item:Token) raises Token -> Self.Out:
        var stop=item.id==2
        var result=self.step.call_mut(carry^,item^)
        if stop: return Self.Out(Break(result^))
        return Self.Out(Continue(result^))

def reduced(var step:Step,var source:Source,mut observed:Int) raises Token -> Optional[Token]:
    try: return Optional(reduce(source^,step^))
    except error:
        if error.isa[EmptyReductionError]():
            observed=-1
            return None
        raise error^.unwrap[ReductionStepError[Token]]().into_error()

def exercise[mode:Int](length:Int,fail:Bool) raises:
    var state=trace()
    var remaining=List[Token]()
    for i in range(length): remaining.append(Token(length-i,state))
    var source=Source(remaining^,Token(5,state))
    var step=Step(Token(6,state),fail)
    var result=Optional[Token]()
    var observed=0
    try:
        comptime if mode==0: result=Optional(fold_left(source^,Token(0,state),step^))
        elif mode==1: result=Optional(iterated(source^).reduce(step^,initial=Token(0,state)))
        elif mode==2: result=iterated(source^).reduce_optional(step^)
        elif mode==3: result=reduced(step^,source^,observed)
        else:
            var stopped=iterated(source^).fold_until(Until(step^),Token(0,state))
            if stopped.isa[Break[Token]](): result=Optional(stopped^.unwrap[Break[Token]]().into_payload())
            else: result=Optional(stopped^.unwrap[Continue[Token]]().into_payload())
    except error:
        comptime assert type_of(error)==Token
        observed=error.id
    var failed=fail and length>=2
    assert_equal(observed,7 if failed else -1 if mode==3 and not length else 0)
    var visited=2 if length>=2 and (failed or mode==4) else length
    assert_equal(state[].calls,max(0,visited-1) if mode==2 or mode==3 else visited)
    assert_equal(state[].pulls,visited if length>=2 and (failed or mode==4) else length+1)
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(failed))
    var carry_id=1 if mode==2 or mode==3 else 0
    if result:
        var value=result.take()
        for i in range(1,length+1): assert_equal(state[].drops[i],Int(i!=carry_id))
        assert_equal(state[].drops[carry_id],0)
        assert_equal(value.id,carry_id)
    for i in range(1,length+1): assert_equal(state[].drops[i],1)
    assert_equal(state[].drops[0],0 if mode==2 or mode==3 else 1)

@fieldwise_init
struct Tail[o:ImmOrigin](MutableBinary):
    comptime First=Span[Int,Self.o]
    comptime Second=Int
    comptime Out=Self.First
    def call_mut(mut self,var carry:Self.First,var item:Int)->Self.Out:return carry[item:]

def external(owner:List[Int])->Span[Int,origin_of(owner)]:
    return iterated([1]).fold_left(Tail[origin_of(owner)](),Span(owner))

def main() raises:
    for length in range(4):
        for fail in range(2):
            comptime for mode in range(5): exercise[mode](length,Bool(fail))
    var owner:List[Int]=[7,11]
    var result=external(owner)
    assert_equal(len(result),1)
    assert_equal(Pointer(to=result[0])==Pointer(to=owner[1]),True)
