"""Owned scans release callbacks, carries, outputs and finite inputs exactly once."""
from fp.callables import MutableBinary
from fp.control import scan, ScanError, ScanStepError, ScanLengthError
from test_map_accumulate_ownership import Source, Step, Keep
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Tick(MutableBinary):
    comptime First=Token
    comptime Second=Tuple[]
    comptime Out=Tuple[Token,Token]
    comptime Error=Token
    var inner:Step
    var calls:Int
    def call_mut(mut self,var carry:Token,var item:Tuple[]) raises Token -> Self.Out:
        self.calls += 1
        return self.inner.call_mut(carry^,Token(self.calls,self.inner.capture.trace))


def exercise[route:Int](fail:Bool) raises:
    var state=trace()
    var saved=Optional[Tuple[Token,List[Token]]]()
    var kind=0
    try:
        comptime if route==0:
            var xs=List[Token]()
            for index in range(1,4): xs.append(Token(index,state))
            saved=Optional(scan(Step(Token(6,state),fail),Token(0,state),xs^))
        elif route==1:
            saved=Optional(scan[static_length=3,unroll=0](Step(Token(6,state),fail),Token(0,state),Source(1,state)))
        elif route==2:
            saved=Optional(scan[unroll=2](Step(Token(6,state),fail),Token(0,state),Source(1,state),reverse=True))
        elif route==3:
            saved=Optional(scan(Step(Token(6,state),fail),Token(0,state),Source(1,state),length=2))
        elif route==4:
            saved=Optional(scan(Step(Token(6,state),fail),Token(0,state),Source(4,state)))
        else:
            saved=Optional(scan[static_length=3,unroll=0](Tick(Step(Token(6,state),fail),0),Token(0,state)))
    except error:
        comptime assert type_of(error)==ScanError[Token]
        if error.isa[ScanStepError[Token]]():
            kind=1
            assert_equal(error[ScanStepError[Token]].error.id,7)
            assert_equal(state[].drops[7],0)
            _=error^
        else:
            kind=2
            assert_equal(error[ScanLengthError].actual,3)
    var failed=fail and (route<3 or route==5)
    assert_equal(kind,2 if route==3 else 1 if failed else 0)
    assert_equal(state[].calls,0 if route==3 or route==4 else 2 if failed else 3)
    assert_equal(state[].pulls,0 if route==0 or route==5 else 1 if route==4 else 4)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(failed))
    if saved:
        var result=saved.take()
        assert_equal(result[0].id,0)
        assert_equal(len(result[1]),0 if route==4 else 3)
        for index in range(1,4):
            assert_equal(state[].drops[index],0)
            if route!=4: assert_equal(result[1][index-1].id,index)
        assert_equal(state[].drops[0],0)
        _=result^
    assert_equal(state[].drops[0],1)
    for index in range(1,4):
        assert_equal(state[].drops[index],0 if route==4 or (route==5 and failed and index==3) else 1)


def external(owner:List[Int]) raises ScanLengthError -> Tuple[Span[Int,origin_of(owner)],List[Span[Int,origin_of(owner)]]]:
    return scan(Keep[origin_of(owner)](),Span(owner),iter(range(2)))


def main() raises:
    for fail in [False,True]:
        comptime for route in range(6): exercise[route](fail)
    var owner:List[Int]=[7,11]
    var output:List[Int]=[13]
    distinct(owner,output)
    error_origins(output)
    var result=external(owner)
    assert_equal(Pointer(to=result[0][0])==Pointer(to=owner[0]),True)
    assert_equal(Pointer(to=result[1][1][0])==Pointer(to=owner[1]),True)


@fieldwise_init
struct Separate[a:ImmOrigin,y:ImmOrigin](MutableBinary):
    comptime First=Span[Int,Self.a]
    comptime Second=Int
    comptime Out=Tuple[Self.First,Span[Int,Self.y]]
    var output:Span[Int,Self.y]
    def call_mut(mut self,var carry:Self.First,var item:Int) -> Self.Out:
        return(carry,self.output)

def distinct(first:List[Int],second:List[Int]) raises:
    var result=scan(Separate[origin_of(first),origin_of(second)](Span(second)),Span(first),iter(range(2)))
    assert_equal(Pointer(to=result[0][0])==Pointer(to=first[0]),True)
    assert_equal(Pointer(to=result[1][1][0])==Pointer(to=second[0]),True)


@fieldwise_init
struct Raise[E:Copyable & Deinitable](MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Tuple[Int,Int]
    comptime Error=Self.E
    var failure:Self.E
    def call_mut(mut self,var carry:Int,var item:Int) raises Self.E -> Self.Out:
        raise self.failure.copy()

def error_origins(owner:List[Int]) raises:
    var view=Span(owner)
    comptime E=type_of(view)
    var caught=False
    try:
        _=scan(Raise[E](view),0,iter(range(1)))
    except error:
        comptime assert type_of(error)==ScanError[E]
        caught=error.isa[ScanStepError[E]]()
        assert_equal(Pointer(to=error[ScanStepError[E]].error[0])==Pointer(to=owner[0]),True)
    assert_equal(caught,True)
