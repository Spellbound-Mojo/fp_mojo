"""Select native binary types before inferring a captured callback."""
from fp.callables import BinarySignature
from fp.functions import flow, partial
from fp.iteration import iterated
from test_composition_then import scale
from std.testing import assert_equal

def values() raises:
    var offset = 7
    def rrr(var first: Int, var second: Int) {offset} -> Int: return first + second + offset
    def rrm(var first: Int, var second: Int) {offset} -> String: return String(first + second + offset)
    def mrr(var first: String, var second: Int) {offset} -> Int: return first.byte_length() + second + offset
    def mrm(var first: String, var second: Int) {offset} -> String: return first + String(second + offset)
    def rmr(var first: Int, var second: String) {offset} -> Int: return first + second.byte_length() + offset
    def rmm(var first: Int, var second: String) {offset} -> String: return String(first + offset) + second
    def mmr(var first: String, var second: String) {offset} -> Int: return first.byte_length() + second.byte_length() + offset
    def mmm(var first: String, var second: String) {offset} -> String: return first + second + String(offset)
    var sum = BinarySignature[Int, Int, Int].capture(rrr)
    comptime assert not type_of(sum).raising
    assert_equal(sum(2, 3), 12)
    assert_equal(BinarySignature[Int, Int, String].capture(rrm)(2, 3), "12")
    assert_equal(BinarySignature[String, Int, Int].capture(mrr)("ab", 3), 12)
    assert_equal(BinarySignature[String, Int, String].capture(mrm)("a", 2), "a9")
    assert_equal(BinarySignature[Int, String, Int].capture(rmr)(2, "abc"), 12)
    assert_equal(BinarySignature[Int, String, String].capture(rmm)(2, "b"), "9b")
    assert_equal(BinarySignature[String, String, Int].capture(mmr)("ab", "c"), 10)
    assert_equal(BinarySignature[String, String, String].capture(mmm)("a", "b"), "ab7")
    assert_equal(iterated(range(2)).zip_with(range(3, 5), sum).collect_list(), [10, 12])
    assert_equal(iterated(range(2)).map_with_index(sum).collect_list(), [7, 9])
    assert_equal(flow(sum^, partial(scale, 2))(2, 3), 24)

def effects() raises:
    var offset = 3
    def raising(var first: Int, var second: Int) raises Int {offset} -> Int: raise first + second + offset
    var callback = BinarySignature[Int, Int, Int, Int].capture(raising)
    comptime assert type_of(callback).Error == Int and type_of(callback).raising
    var observed = 0
    try: _ = callback(1, 2)
    except error: observed = error
    assert_equal(observed, 6)
    def never(var first: Int, var second: Int) raises Never {offset} -> Int: return first + second + offset
    var impossible = BinarySignature[Int, Int, Int].capture(never)
    comptime assert type_of(impossible).raising
    assert_equal(impossible(1, 2), 6)
    var total = 0
    def observe(var first: Int, var second: Int) {mut total}:
        total += first + second
    var observer = BinarySignature[Int, Int, type_of(None)].capture(observe)
    observer(2, 3)
    observer(1, 2)
    _ = observer^
    assert_equal(total, 8)
    def observe_never(var first: Int, var second: Int) raises Never {mut total}:
        total += first + second
    var no_error = BinarySignature[Int, Int, type_of(None)].capture(observe_never)
    comptime assert type_of(no_error).raising
    no_error(1, 2)
    _ = no_error^
    assert_equal(total, 11)
    def void_error(var first: Int, var second: Int) raises Int {offset}: raise first + second + offset
    try: BinarySignature[Int, Int, type_of(None), Int].capture(void_error)(2, 3)
    except error: observed = error
    assert_equal(observed, 8)
    def unit(var first: Int, var second: Int) {offset} -> NoneType:
        _ = first + second + offset
        return None
    var explicit = BinarySignature[Int, Int, NoneType].capture(unit)
    comptime assert type_of(explicit).Out == NoneType
    _ = explicit(1, 2)

def plain_procedure(var first: Int, var second: Int):
    _ = first
    _ = second

def main() raises:
    values()
    effects()
    # A plain declaration can be contextualized to an explicit unit result.
    # The selected signature, not the declaration's unbound default, is stored.
    var contextual = BinarySignature[Int, Int, NoneType].capture(plain_procedure)
    comptime assert type_of(contextual).Out == NoneType
    _ = contextual(1, 2)
