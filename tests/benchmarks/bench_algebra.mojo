"""Library operations against hand-written native loops on identical inputs.

The suite runs this program at O3 and reports each line as a diagnostic; the
timings never fail the suite. Equal checksums show both sides did the same work.
Each line is `bench <name> native_ns=<median> library_ns=<median> samples=<n>`.
"""
from std.time import perf_counter_ns
from std.utils import Variant
from std.testing import assert_equal
from std.builtin.rebind import rebind_var
from fp.algebra import map, traverse, ResultFamily, IdentityFamily, ListFamily, Applicative
from fp.callables import Unary, UnaryContract, BinaryContract, ThunkContract
from fp.data import Result, Ok, Err


def mix(value:Int)->Int:
    return (value*1664525+1013904223) & 268435455


@fieldwise_init
struct Mix(Unary,Defaultable):
    comptime Arg = Int
    comptime Out = Int
    def call(self,var value:Int)->Int:
        return mix(value)


struct IdentityApplicative(Applicative):
    # Exercise the Applicative-only collection algorithm independently of Monad.
    comptime Element[V:Movable & Deinitable] = V
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = IdentityFamily.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = IdentityFamily.MapError[V,F]
    comptime Pure[A:Movable & Deinitable] = IdentityFamily.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = IdentityFamily.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = IdentityFamily.CombineError[V,F,R]
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return IdentityFamily.map(f^,value^)
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A) -> Self.Pure[A]:
        return IdentityFamily.pure(value^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](
        var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]:
        return IdentityFamily.map2_lazy(f^,left^,right^)


@no_inline
def mapped[library:Bool](n:Int,seed:Int)->Int:
    var value=seed
    for index in range(n):
        comptime if library:
            var input=Result[Int,Int](Ok(value)) if index%64 else Result[Int,Int](Err(value))
            var output=map[ResultFamily[Int]](Mix(),input^)
            try:
                value=output^.raise_on_err()
            except error:
                value=error+1
        else:
            var input=Variant[Ok[Int],Err[Int]](Ok(value)) if index%64 else Variant[Ok[Int],Err[Int]](Err(value))
            if input.isa[Ok[Int]]():
                value=mix(input^.unwrap[Ok[Int]]().value)
            else:
                value=input^.unwrap[Err[Int]]().value+1
    return value


@no_inline
def collected[library:Bool](n:Int,seed:Int)->Int:
    var checksum=0
    var code=seed
    for batch in range(n):
        var source=List[Int]()
        for index in range(1024):
            code=mix(code)
            source.append(code+index+batch)
        var result:List[Int]
        comptime if library:
            result=traverse[ListFamily,IdentityApplicative](Mix(),source^)
        else:
            result=List[Int]()
            for item in source^:
                result.append(mix(item))
        for value in result:
            checksum += value
    return checksum


def sample[kind:Int,library:Bool](count:Int,seed:Int)->Tuple[Int,Int]:
    var start=perf_counter_ns()
    var checksum:Int
    comptime if kind==0:
        checksum=mapped[library](count,seed)
    else:
        checksum=collected[library](count,seed)
    return (Int(perf_counter_ns()-start),checksum)


def median(var samples:List[Int])->Int:
    for i in range(1,len(samples)):
        var j=i
        while j>0 and samples[j-1]>samples[j]:
            samples.swap_elements(j-1,j)
            j-=1
    return samples[len(samples)//2]


def paired[kind:Int](name:String,count:Int) raises:
    _ = sample[kind,False](count,17)
    _ = sample[kind,True](count,17)
    var native=List[Int]()
    var library=List[Int]()
    for index in range(9):
        # Alternate order; each checksum makes the measured result observable.
        var first:Tuple[Int,Int]
        var second:Tuple[Int,Int]
        if index%2:
            second=sample[kind,True](count,17+index)
            first=sample[kind,False](count,17+index)
        else:
            first=sample[kind,False](count,17+index)
            second=sample[kind,True](count,17+index)
        assert_equal(first[1],second[1])
        native.append(first[0])
        library.append(second[0])
    print("bench",name,"native_ns="+String(median(native^)),"library_ns="+String(median(library^)),"samples=9")


def main() raises:
    paired[0]("result_map",5000000)
    paired[1]("list_traverse",4096)
