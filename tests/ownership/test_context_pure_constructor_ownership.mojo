from fp.algebra import Applicative, IdentityFamily, OptionalFamily, ResultFamily, ListFamily, StringMonoid, pure
from fp.effects import WriterT,ReaderT,StateT,OptionalT,ResultT,run,run_writer
from test_applicative_error_ownership import AEOOwner as Owner
from test_writer_capabilities import WCMoveLogMonoid
from std.memory import ArcPointer
from std.testing import assert_equal

def construct[I:Applicative,A:Movable & Deinitable](var value:A)->I.Pure[A]:
    return pure[I](value^)

def discarded[I:Applicative]() raises:
    var drops=ArcPointer(0)
    var value=construct[I](Owner(7,drops))
    assert_equal(drops[],0)
    _=value^
    assert_equal(drops[],1)

def main() raises:
    discarded[WriterT[IdentityFamily,WCMoveLogMonoid]]()
    discarded[WriterT[OptionalFamily,WCMoveLogMonoid]]()
    discarded[WriterT[ResultFamily[String],WCMoveLogMonoid]]()
    discarded[WriterT[ListFamily,WCMoveLogMonoid]]()
    comptime W=WriterT[OptionalFamily,WCMoveLogMonoid]
    comptime R=ReaderT[W,Int]
    comptime S=StateT[W,Owner]
    discarded[R]()
    discarded[S]()
    discarded[OptionalT[W]]()
    discarded[ResultT[W,String]]()
    var drops=ArcPointer(0)
    var state_drops=ArcPointer(0)
    var reader=run_writer[W](run[R](construct[R](Owner(11,drops)),0))
    assert_equal(reader.value()[1].value,11)
    _=reader^
    assert_equal(drops[],1)
    var state=run_writer[W](run[S](construct[S](Owner(13,drops)),Owner(17,state_drops)))
    assert_equal(state.value()[1][0].value,13)
    assert_equal(state.value()[1][1].value,17)
    _=state^
    assert_equal(drops[],2)
    assert_equal(state_drops[],1)
