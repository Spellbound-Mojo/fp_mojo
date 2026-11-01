"""Stored projection pointers preserve read/result ABIs, units and errors."""
from fp.effects import Reader, State, asks, inspect, run
from std.testing import assert_equal


def rr(value: Int) -> Int: return value + 1
def replacement(value: Int) -> Int: return value * 10
def rm(value: Int) -> String: return String(value)
def mr(value: String) -> Int: return value.byte_length()
def mm(value: String) -> String: return value.copy()
def void_register(value: Int): pass
def void_memory(value: String): pass
def explicit_none(value: Int) -> NoneType: return None
def never(value: String) raises Never -> String: return value.copy()
def never_void(value: Int) raises Never: pass
def fail(value: String) raises Int -> Int: raise value.byte_length()
def fail_void(value: Int) raises Int: raise value


@fieldwise_init
struct ProjectionInput:
    var value: Int


def project_input(value: ProjectionInput) -> Int: return value.value


def generic_read[P: AnyType, R: Movable & Deinitable](value: P, function: def(P) thin -> R) -> R where not conforms_to(P,TrivialRegisterPassable) and not conforms_to(R,RegisterPassable):
    return run[Reader[P]](asks[Reader[P]](function),value)


def main() raises:
    var number = 7
    var text = String("word")
    var p0: def(Int) thin -> Int = rr
    var p1: def(Int) thin -> String = rm
    var p2: def(String) thin -> Int = mr
    var p3: def(String) thin -> String = mm
    assert_equal(run[Reader[Int]](asks[Reader[Int]](p0),number),8)
    assert_equal(run[Reader[Int]](asks[Reader[Int]](p1),number),"7")
    assert_equal(run[Reader[String]](asks[Reader[String]](p2),text),4)
    assert_equal(run[Reader[String]](asks[Reader[String]](p3),text),"word")
    assert_equal(run[State[Int]](inspect[State[Int]](p0),number),(8,7))
    assert_equal(run[State[Int]](inspect[State[Int]](p1),number),(String("7"),7))
    assert_equal(run[State[String]](inspect[State[String]](p2),text.copy()),(4,String("word")))
    assert_equal(run[State[String]](inspect[State[String]](p3),text.copy()),(String("word"),String("word")))
    assert_equal(generic_read(text,p3),"word")

    var pending = asks[Reader[Int]](p0)
    p0 = replacement
    assert_equal(run[Reader[Int]](pending^,number),8)
    assert_equal(run[Reader[Int]](asks[Reader[Int]](p0),number),70)

    var vr: def(Int) thin = void_register
    var vm: def(String) thin = void_memory
    _ = run[Reader[Int]](asks[Reader[Int]](vr),number)
    _ = run[Reader[String]](asks[Reader[String]](vm),text)
    var unit = run[State[Int]](inspect[State[Int]](vr),number)
    comptime assert type_of(unit[0]) == type_of(None)
    assert_equal(unit[1],7)
    var memory_unit = run[State[String]](inspect[State[String]](vm),text.copy())
    assert_equal(memory_unit[1],"word")
    var boxed: def(Int) thin -> NoneType = explicit_none
    var boxed_unit = run[State[Int]](inspect[State[Int]](boxed),number)
    comptime assert type_of(boxed_unit[0]) == NoneType
    assert_equal(boxed_unit[1],7)
    var pn: def(String) raises Never thin -> String = never
    assert_equal(run[Reader[String]](asks[Reader[String]](pn),text),"word")
    assert_equal(run[State[String]](inspect[State[String]](pn),text.copy()),(String("word"),String("word")))
    var pnv: def(Int) raises Never thin = never_void
    _ = run[Reader[Int]](asks[Reader[Int]](pnv),number)
    _ = run[State[Int]](inspect[State[Int]](pnv),number)

    var raising: def(String) raises Int thin -> Int = fail
    var raising_void: def(Int) raises Int thin = fail_void
    var failure = 0
    try: _ = run[Reader[String]](asks[Reader[String]](raising),text)
    except error: failure = error
    assert_equal(failure,4)
    failure = 0
    try: _ = run[State[String]](inspect[State[String]](raising),text.copy())
    except error: failure = error
    assert_equal(failure,4)
    try: _ = run[Reader[Int]](asks[Reader[Int]](raising_void),number)
    except error: failure = error
    assert_equal(failure,7)
    failure = 0
    try: _ = run[State[Int]](inspect[State[Int]](raising_void),number)
    except error: failure = error
    assert_equal(failure,7)

    var environment = ProjectionInput(23)
    var pf: def(ProjectionInput) thin -> Int = project_input
    assert_equal(run[Reader[ProjectionInput]](asks[Reader[ProjectionInput]](pf),environment),23)
