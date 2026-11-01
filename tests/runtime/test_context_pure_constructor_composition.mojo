from fp.algebra import Applicative, OptionalFamily, StringMonoid, pure
from fp.effects import ReaderT,StateT,OptionalT,ResultT,WriterT,run,run_writer
from std.testing import assert_equal

comptime W=WriterT[OptionalFamily,StringMonoid]

def generic[I:Applicative]()->I.Pure[Int]:return pure[I](7)

def main() raises:
    var direct=run_writer[W](generic[W]())
    assert_equal(direct.value()[1],7)
    comptime R=ReaderT[W,Int]
    var reader=run_writer[W](run[R](generic[R](),0))
    assert_equal(reader.value()[1],7)
    comptime S=StateT[W,Int]
    var state=run_writer[W](run[S](generic[S](),3))
    assert_equal(state.value()[1][0],7)
    assert_equal(state.value()[1][1],3)
    comptime O=OptionalT[W]
    var optional=run_writer[W](generic[O]())
    assert_equal(optional.value()[1].value(),7)
    comptime T=ResultT[W,String]
    var result=run_writer[W](generic[T]())
    assert_equal(result.value()[1]._ok().value,7)
