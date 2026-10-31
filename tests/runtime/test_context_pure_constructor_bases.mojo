"""Public pure specializes payload construction without changing native storage."""
from fp.algebra import Applicative, IdentityFamily, OptionalFamily, ResultFamily, ListFamily, StringMonoid, pure
from fp.effects import WriterT,run_writer
from std.testing import assert_equal

def generic[I:Applicative,A:Movable & Deinitable](var value:A)->I.Pure[A]:
    return pure[I](value^)

def main() raises:
    comptime W=WriterT[IdentityFamily,StringMonoid]
    comptime O=WriterT[OptionalFamily,StringMonoid]
    comptime R=WriterT[ResultFamily[String],StringMonoid]
    comptime L=WriterT[ListFamily,StringMonoid]
    var identity=run_writer[W](generic[W](1))
    assert_equal(identity[0],"")
    assert_equal(identity[1],1)
    var optional=run_writer[O](generic[O](2))
    assert_equal(optional.value()[0],"")
    assert_equal(optional.value()[1],2)
    var result=run_writer[R](generic[R](3))
    assert_equal(result._ok().value[0],"")
    assert_equal(result._ok().value[1],3)
    var list=run_writer[L](generic[L](4))
    assert_equal(len(list),1)
    assert_equal(list[0][0],"")
    assert_equal(list[0][1],4)
    # Concrete dictionary calls retain their existing spelling and representation.
    var concrete=run_writer[O](O.pure(5))
    assert_equal(concrete.value()[1],5)
