"""Owned scan steps share ordering, length validation and receiver contracts."""
from std.builtin.rebind import rebind_var
from fp.control import scan, ScanLengthError, ScanError, ScanStepError
from fp.callables import Binary, MutableBinary, OnceBinary, BinaryContract, RepeatableBinary, mut_ref
from std.testing import assert_equal
@fieldwise_init
struct Step[Empty: Bool = False](MutableBinary):
    comptime First = Int
    comptime Second = Tuple[] if Self.Empty else Int
    comptime Out = Tuple[Int, String]
    var calls: Int
    def call_mut(mut self, var carry: Int, var value: Self.Second) -> Self.Out:
        self.calls += 1
        comptime if Self.Empty:
            carry += self.calls
        else:
            comptime assert Self.Second == Int
            carry += self.calls * rebind_var[Int](value)
        return (carry,String(carry))
@fieldwise_init
struct Modes(Binary,MutableBinary,OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int,Int]
    var calls: Int
    def call(self,var carry:Int,var value:Int)->Self.Out: return(carry+value,0)
    def call_mut(mut self,var carry:Int,var value:Int)->Self.Out:
        self.calls += 1
        return(carry+value*self.calls,self.calls)
    def call_once(deinit self,var carry:Int,var value:Int)->Self.Out: return(999,999)
def verify() raises ScanLengthError -> Bool:
    var a:List[Int]=[1,2,3]
    var first = scan(Step(0),0,a^)
    var second = scan[String,unroll=2](Step(0),0,iter(range(1,4)))
    var third = scan[static_length=3,unroll=0](Step[True](0),0)
    var retained=Step(0)
    var fourth=scan(mut_ref(retained),0,iter(range(1,4)),reverse=True)
    var named=Modes(0)
    var shared=scan(named,0,iter(range(1,4)))
    var owned=scan(named^,0,iter(range(1,4)))
    return first[0]==14 and first[1][2]=='14' and second[0]==14 and third[0]==6 and fourth[0]==10 and retained.calls==3 and shared[0]==6 and owned[0]==14
def main() raises:
    var passed:Bool
    try:
        passed=verify()
    except:
        raise Error("unexpected scan error")
    assert_equal(passed,True)
    contracts()


def forward[A: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable,
            F: BinaryContract & Movable & Deinitable](var step:F,var carry:A,var xs:List[X]
) raises ScanError[F.Error] -> Tuple[A,List[Y]] where RepeatableBinary[F] and F.First==A and F.Second==X and F.Out==Tuple[A,Y]:
    return scan[Y,unroll=2](step^,carry^,xs^)

@fieldwise_init
struct Stop(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Tuple[Int,Int]
    comptime Error=StopIteration
    var calls:Int
    def call_mut(mut self,var carry:Int,var item:Int) raises StopIteration -> Self.Out:
        self.calls += 1
        raise StopIteration()

def contracts() raises:
    var values:List[Int]=[1,2,3]
    var result=forward(Step(0),0,values^)
    assert_equal(result[0],14)
    var step=Step(0)
    var empty=scan(mut_ref(step),7,List[Int]())
    assert_equal(empty[0],7)
    assert_equal(len(empty[1]),0)
    assert_equal(step.calls,0)
    var caught=False
    try:
        _=scan(mut_ref(step),0,iter(range(3)),length=2)
    except error:
        caught=True
        assert_equal(error.expected,2)
        assert_equal(error.actual,3)
    assert_equal(caught,True)
    assert_equal(step.calls,0)
    var stop=Stop(0)
    caught=False
    try:
        _=scan(mut_ref(stop),0,iter(range(3)))
    except error:
        comptime assert type_of(error)==ScanError[StopIteration]
        caught=error.isa[ScanStepError[StopIteration]]()
    assert_equal(caught,True)
    assert_equal(stop.calls,1)
