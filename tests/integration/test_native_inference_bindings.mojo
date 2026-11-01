"""Exact result constraints preserve positional callbacks and named output types."""
from fp.data import Result, Ok, Err, ControlFlow, Continue
from fp.functions import pipeline
from fp.iteration import fold_left, fold_until, reduce, reduce_optional, find, collect_list, filter_map, scan_left
from std.testing import assert_equal

@fieldwise_init
struct BindingFailure(Movable):
    var value: Int

def main() raises:
    var bias = 0
    def binding_read(value: Int) {bias} -> Int: return value + 1
    def binding_owned(var value: Int) {bias} -> Int: return value + 2
    def binding_recover(var value: Int) {bias} -> Result[Int, Int]: return Ok(value + 3)
    def binding_raise(var value: Int) raises BindingFailure {bias} -> Int: raise BindingFailure(value)
    def binding_add(var carry: Int, var value: Int) {bias} -> Int: return carry + value
    def binding_continue(var carry: Int, var value: Int) {bias} -> ControlFlow[Int, Int]: return Continue(carry + value)
    def binding_predicate(value: Int) {bias} -> Bool: return value > 1
    def binding_optional(var value: Int) {bias} -> Optional[Int]: return Optional(value + 4)

    var ok = Result[Int, Int](Ok(7))
    assert_equal(ok.fold[type_of(binding_read), type_of(binding_read)](binding_read, binding_read), 8)
    assert_equal(ok^.fold_owned[type_of(binding_owned), type_of(binding_owned)](binding_owned, binding_owned), 9)
    assert_equal(Result[Int, Int](Ok(7)).fold[R=Int](binding_read, binding_read), 8)
    var error = Result[Int, Int](Err(5))
    var mapped = error^.map_err[type_of(binding_owned)](binding_owned)
    assert_equal(mapped.fold(binding_read, binding_read), 8)
    var named = Result[Int, Int](Err(5)).map_err[U=Int](binding_owned)
    assert_equal(named.fold(binding_read, binding_read), 8)
    var original = Result[Int, Int](Err(5))
    var recovered = original^.or_else[type_of(binding_recover)](binding_recover)
    assert_equal(recovered.fold(binding_read, binding_read), 9)
    var failed = Result[Int, Int](Err(12))
    try:
        _ = failed^.map_err[BindingFailure, type_of(binding_raise)](binding_raise)
        debug_assert[assert_mode="safe"](False, "missing callback error")
    except error:
        comptime assert type_of(error) == BindingFailure
        assert_equal(error.value, 12)
    assert_equal(fold_left[type_of(binding_add)](range(4), 10, binding_add), 16)
    assert_equal(reduce[type_of(binding_add)](range(4), binding_add), 6)
    var optional = reduce_optional[type_of(binding_add)](range(4), binding_add)
    assert_equal(optional.take(), 6)
    var continued = fold_until[type_of(binding_continue), Int](range(4), 10, binding_continue)
    assert_equal(continued[Continue[Int]].value, 16)
    var found = find[type_of(binding_predicate)](range(4), binding_predicate)
    assert_equal(found.take(), 2)
    var present = collect_list(filter_map[type_of(binding_optional)](range(2), binding_optional))
    assert_equal(present, List[Int]([4, 5]))
    var snapshots = collect_list(scan_left[type_of(binding_add)](range(3), 10, binding_add))
    assert_equal(snapshots, List[Int]([10, 10, 11, 13]))
    var selected = pipeline(List[Int]([1, 2, 3])).filter(binding_predicate).get()
    assert_equal(selected, List[Int]([2, 3]))
