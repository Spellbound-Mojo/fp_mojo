# error: writer: value belongs to a different writer family
from fp.algebra import pure, StringMonoid
from fp.effects import Reader, WriterT, run_writer

comptime W=WriterT[Reader[Int],StringMonoid]
comptime Other=WriterT[Reader[String],StringMonoid]
comptime P=W.Pure[Int]
comptime Q=Other.Pure[Int]
comptime Pair=W._Joined[P,Q]

def main():
    # Both leaves advertise Int; the nested foreign family must still fail
    # admission, even though this execution would select the valid sibling.
    var inner=W._join_left[P,Q](pure[W](3))
    var outer=W._join_left[Pair,P](inner^)
    _=run_writer[W](outer^)
