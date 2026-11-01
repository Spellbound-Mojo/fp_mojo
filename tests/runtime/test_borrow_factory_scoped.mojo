"""Scoped IO keeps pointer ABIs and an inferred generic action witness."""
from fp.effects import IO, IOContract, Outcome, ReaderAction, lift_resource, pure_resource, run_io, scoped_io
from test_resource_thin import RegisterIO, checked, failed, rr, rr_other, mr, rm, mm, never, raising


def forwarded[P: Movable & Deinitable, R: ReaderAction](var value: P, function: def(P) thin -> R) -> Outcome[R.Value,Int] where IOContract[R].Compatible and IOContract[R].Error == Int and not conforms_to(P,TrivialRegisterPassable) and not conforms_to(R,RegisterPassable):
    return run_io(lift_resource(pure_resource[Int](value^)).use(scoped_io(function)))


def main() raises:
    var a: def(Int) thin -> RegisterIO = rr
    var b: def(String) thin -> RegisterIO = mr
    var c: def(Int) thin -> IO[Int].Pure[Int] = rm
    var d: def(String) thin -> IO[Int].Pure[Int] = mm
    checked(run_io(lift_resource(pure_resource[Int](7)).use(scoped_io(a))),7)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).use(scoped_io(b))),4)
    checked(run_io(lift_resource(pure_resource[Int](8)).use(scoped_io(c))),8)
    checked(forwarded(String("words"),d),5)
    checked(run_io(lift_resource(pure_resource[Int](9)).eval_map(scoped_io(c)).use(c)),9)
    checked(run_io(lift_resource(pure_resource[Int](10)).eval_tap(scoped_io(c)).use(c)),10)
    var saved = scoped_io(a)
    a = rr_other
    checked(run_io(lift_resource(pure_resource[Int](11)).use(saved^)),11)
    checked(run_io(lift_resource(pure_resource[Int](11)).use(scoped_io(a))),110)
    var n: def(Int) raises Never thin -> RegisterIO = never
    checked(run_io(lift_resource(pure_resource[Int](12)).use(scoped_io(n))),12)
    var e: def(Int) raises Int thin -> RegisterIO = raising
    checked(run_io(lift_resource(pure_resource[Int](13)).use(scoped_io(e))),13)
    failed(run_io(lift_resource(pure_resource[Int](-1)).use(scoped_io(e))))
