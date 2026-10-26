"""Deferred n-ary calls own pointers and release each move-only operand once."""
from fp.functions import pipeline
from fp.effects import Reader, run
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct NaryOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def total(var a: NaryOwner, var b: String, var c: NaryOwner) -> Int:
    return a.id + b.byte_length() + c.id
def changed(var a: NaryOwner, var b: String, var c: NaryOwner) -> Int: return -1
def fail(var a: NaryOwner, var b: String, var c: NaryOwner) raises Int -> Int:
    raise a.id + c.id

def main() raises:
    comptime Deferred = Reader[Int]
    var drops = ArcPointer(0)
    var pointer: def(var NaryOwner, var String, var NaryOwner) thin -> Int = total
    var pending = pipeline[Deferred](Deferred.pure(NaryOwner(1, drops))).map_n((Deferred.pure(String("b")), Deferred.pure(NaryOwner(3, drops))), pointer).get()
    pointer = changed
    _ = pointer
    assert_equal(drops[], 0)
    assert_equal(run[Deferred](pending^, 0), 5)
    assert_equal(drops[], 2)
    pointer = total
    var abandoned = pipeline[Deferred](Deferred.pure(NaryOwner(1, drops))).map_n((Deferred.pure(String("b")), Deferred.pure(NaryOwner(3, drops))), pointer).get()
    _ = abandoned^
    assert_equal(drops[], 4)
    var raising: def(var NaryOwner, var String, var NaryOwner) raises Int thin -> Int = fail
    var deferred_failure = pipeline[Deferred](Deferred.pure(NaryOwner(1, drops))).raising[Int]().map_n((Deferred.pure(String("b")), Deferred.pure(NaryOwner(3, drops))), raising).get()
    assert_equal(drops[], 4)
    var code = 0
    try: _ = run[Deferred](deferred_failure^, 0)
    except error: code = error
    assert_equal(code, 4)
    assert_equal(drops[], 6)
    var skipped = pipeline(Result[NaryOwner, List[String]](Err(List[String](["first"])))).par_map_n((Result[String, List[String]](Ok(String("b"))), Result[NaryOwner, List[String]](Ok(NaryOwner(3, drops)))), pointer).get()
    assert_equal(skipped._err().value, List[String](["first"]))
    assert_equal(drops[], 7)
