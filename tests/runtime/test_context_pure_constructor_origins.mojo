from fp.algebra import Applicative, OptionalFamily, StringMonoid, pure
from fp.effects import WriterT,WriterValue,ReaderT,run,run_writer
from std.testing import assert_equal

def construct[I:Applicative,A:Movable & Deinitable](var value:A)->I.Pure[A]:return pure[I](value^)

def check(owner:List[Int]) raises:
    comptime V=type_of(Span(owner))
    comptime W=WriterT[OptionalFamily,StringMonoid]
    comptime assert W.Pure[V] == WriterValue[W,V,Optional[Tuple[String,V]]]
    var direct=run_writer[W](construct[W](Span(owner)))
    assert_equal(direct.value()[1].unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    comptime R=ReaderT[W,Int]
    var nested=run_writer[W](run[R](construct[R](Span(owner)),0))
    assert_equal(nested.value()[1].unsafe_ptr()==Span(owner).unsafe_ptr(),True)

def main() raises:check([7,8])
