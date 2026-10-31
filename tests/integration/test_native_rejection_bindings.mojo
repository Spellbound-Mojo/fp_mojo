"""Valid counterparts to native convention and arity rejection fixtures.

Explicit callback types bypass Mojo 1.2's invalid-signature inference crash.
These calls prove that the bindings still select working native overloads.
"""
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import as_unary
from fp.data import Result, Ok, Err, Capture
from fp.functions import pipe, pipeline
from fp.iteration import iterated
from std.builtin.variadics import TypeList
from std.testing import assert_equal

@fieldwise_init
struct RejectionBindingOwner(Movable):
    var value: Int

def rb_mutate(mut value: RejectionBindingOwner) -> Int:
    value.value += 1
    return value.value

def rb_tuple(var value: Tuple[Int, String]) -> Int:
    return value[0] + value[1].byte_length()

def rb_add(a: Int, b: Int) -> Int: return a + b
def rb_key(value: RejectionBindingOwner) -> Int: return value.value + 1
def rb_select(value: Int) -> Bool: return value > 1
def rb_effect(value: RejectionBindingOwner) -> Optional[Bool]: return Optional(value.value > 0)
def rb_project(value: RejectionBindingOwner) -> Result[Int, String]: return Ok(value.value + 1)
def rb_outcome(value: Result[RejectionBindingOwner, String]) -> Result[Int, String]: return Ok(0)
def rb_error(error: RejectionBindingOwner) -> Result[Int, RejectionBindingOwner]: return Ok(error.value)
def rb_predicate(error: RejectionBindingOwner) -> Bool: return error.value > 0
def rb_recover(var error: RejectionBindingOwner) -> Int: return error.value + 1
def rb_string_predicate(error: String) -> Bool: return error.byte_length() > 0
def rb_string_recover(var error: String) -> Int: return error.byte_length()
def rb_inspect(error: String) -> Int: return error.byte_length()
def rb_optional(value: String) -> Optional[Int]: return Optional(value.byte_length())
def rb_shared_outcome(value: Result[Int, String]) -> Result[Int, String]: return Ok(0)
def rb_factory(value: Int) -> String: return "rejected"
def rb_filter_effect(value: String) -> Optional[Bool]: return Optional(value.byte_length() > 1)
def rb_traverse(value: RejectionBindingOwner) -> Optional[Int]: return Optional(value.value + 1)

def main() raises:
    var value = RejectionBindingOwner(3)
    var attempted = Capture.mutable(value).run(rb_mutate)
    assert_equal(attempted._ok().value, 4)
    assert_equal(value.value, 4)

    var unary = as_unary[F=type_of(rb_tuple)](rb_tuple)
    assert_equal(pipe((1, String("xy")), unary), 3)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    assert_equal(pipe[Path]((2, String("xyz")), unary), 5)
    var summed = pipeline(Optional(1)).map_n((Optional(2),), rb_add).get()
    assert_equal(summed.take(), 3)

    var owners = List[RejectionBindingOwner]()
    owners.append(RejectionBindingOwner(5))
    var paired = pipeline(owners^).pair_with(rb_key).get()
    assert_equal(paired[0][0].value, 5)
    assert_equal(paired[0][1], 6)
    var selected = pipeline(List[Int]([1, 2, 3])).filter(rb_select).get()
    assert_equal(selected, List[Int]([2, 3]))
    var rejected = pipeline(List[Int]([1, 2, 3])).filter_not(rb_select).get()
    assert_equal(rejected, List[Int]([1]))
    var checked = List[RejectionBindingOwner]()
    checked.append(RejectionBindingOwner(1))
    var all_present = iterated(checked^).all_effect[OptionalFamily, F=type_of(rb_effect)](rb_effect)
    assert_equal(all_present.take(), True)

    var projected = Result[RejectionBindingOwner, String](Ok(RejectionBindingOwner(7))).flat_tap[C=type_of(rb_project)](rb_project)
    assert_equal(projected._ok().value.value, 7)
    var observed = Result[RejectionBindingOwner, String](Ok(RejectionBindingOwner(8))).attempt_tap[C=type_of(rb_outcome)](rb_outcome)
    assert_equal(observed._ok().value.value, 8)
    var error = Result[Int, RejectionBindingOwner](Err(RejectionBindingOwner(9))).flat_tap_err[C=type_of(rb_error)](rb_error)
    assert_equal(error._err().value.value, 9)
    var recovered = Result[Int, RejectionBindingOwner](Err(RejectionBindingOwner(10))).recover_if[C=type_of(rb_predicate)](rb_predicate, rb_recover)
    assert_equal(recovered._ok().value, 11)

    var restored = pipeline[ResultFamily[String]](Result[Int, String](Err(String("bad")))).recover_if(rb_string_predicate, rb_string_recover).get()
    assert_equal(restored._ok().value, 3)
    var logged = pipeline[ResultFamily[String]](Result[Int, String](Err(String("original")))).tap_err(rb_inspect).get()
    assert_equal(logged._err().value, "original")
    var retained = pipeline(Optional(String("owned"))).flat_tap(rb_optional).get()
    assert_equal(retained.take(), "owned")
    var retained_pair = pipeline(Optional(String("owned"))).flat_pair_with(rb_optional).get()
    assert_equal(retained_pair.take(), (String("owned"), 5))
    var shared = pipeline[ResultFamily[String]](Result[Int, String](Ok(12))).attempt_tap(rb_shared_outcome).get()
    assert_equal(shared._ok().value, 12)
    var ensured = pipeline[ResultFamily[String]](Result[Int, String](Ok(0))).ensure(rb_select, rb_factory).get()
    assert_equal(ensured._err().value, "rejected")

    var filtered = pipeline(List[String]([String("a"), String("two")])).filter_effect[OptionalFamily](rb_filter_effect).get()
    assert_equal(filtered.take(), List[String]([String("two")]))
    var traversed = List[RejectionBindingOwner]()
    traversed.append(RejectionBindingOwner(13))
    var tapped = pipeline(traversed^).traverse_tap[OptionalFamily](rb_traverse).get()
    var kept = tapped.take()
    assert_equal(kept[0].value, 13)
