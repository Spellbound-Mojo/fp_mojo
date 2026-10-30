from fp.iteration import map_accumulate, iterated
from fp.callables import MutableBinary, BinarySignature
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.iter import Iterator
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element = Token
    var next_id: Int
    var state: ArcPointer[Trace]
    def __next__(mut self) raises StopIteration -> Token:
        self.state[].pulls += 1
        if self.next_id == 4: raise StopIteration()
        self.next_id += 1
        return Token(self.next_id - 1, self.state)

@fieldwise_init
struct Step(MutableBinary):
    comptime First = Token
    comptime Second = Token
    comptime Out = Tuple[Token,Token]
    comptime Error = Token
    var capture: Token
    var fail: Bool
    def call_mut(mut self,var carry: Token,var item: Token) raises Token -> Self.Out:
        self.capture.trace[].calls += 1
        if self.fail and item.id == 2: raise Token(7,self.capture.trace)
        return(carry^,item^)

def main() raises:
    origins()
    for scenario in range(4):
        var fail=Bool(scenario%2)
        var native=scenario>=2
        var state = trace()
        var saved = Optional[Tuple[Token,List[Token]]]()
        try:
            if native:
                var capture=Token(6,state)
                @always_inline
                def callback(var carry:Token,var item:Token) raises Token {var capture^,fail} -> Tuple[Token,Token]:
                    capture.trace[].calls += 1
                    if fail and item.id==2: raise Token(7,capture.trace)
                    return(carry^,item^)
                var step=BinarySignature[Token,Token,Tuple[Token,Token],Token].capture(callback^)
                saved=Optional(iterated(Source(1,state)).map_accumulate(step^,Token(0,state)))
            else:
                saved=Optional(map_accumulate(Source(1,state),Token(0,state),Step(Token(6,state),fail)))
        except error:
            comptime assert type_of(error)==Token
            assert_equal(error.id,7)
        assert_equal(state[].calls,2 if fail else 3)
        assert_equal(state[].pulls,2 if fail else 4)
        assert_equal(state[].drops[6],1)
        if fail:
            for i in range(3): assert_equal(state[].drops[i],1)
            assert_equal(state[].drops[3],0)
            assert_equal(state[].drops[7],1)
        else:
            for i in range(4): assert_equal(state[].drops[i],0)
            var result=saved.take()
            assert_equal(result[0].id,0)
            assert_equal(len(result[1]),3)
            for i in range(3): assert_equal(result[1][i].id,i+1)
        for i in range(3 if fail else 4): assert_equal(state[].drops[i],1)

@fieldwise_init
struct Keep[o: ImmOrigin](MutableBinary):
    comptime First = Span[Int, Self.o]
    comptime Second = Int
    comptime Out = Tuple[Self.First, Self.First]
    def call_mut(mut self,var carry: Self.First,var item: Int) -> Self.Out:
        return (carry,carry[item:])

def external(owner: List[Int]) -> Tuple[Span[Int,origin_of(owner)],List[Span[Int,origin_of(owner)]]]:
    return map_accumulate([0,1],Span(owner),Keep[origin_of(owner)]())

def origins() raises:
    var owner: List[Int] = [7,11]
    var result=external(owner)
    assert_equal(Pointer(to=result[0][0])==Pointer(to=owner[0]),True)
    assert_equal(Pointer(to=result[1][1][0])==Pointer(to=owner[1]),True)
