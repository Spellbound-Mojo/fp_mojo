"""Error mapping preserves the selected policy and validates explicit targets."""
from fp.algebra import ErrorRecovery, ApplicativeError, ErrorMapping, ResultFamily, ValidationFamily, StringMonoid, ListMonoid, Semigroup
from fp.algebra.contracts import MapErrContract
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from context_error_mapping_support import MappingOnly, Envelope, EnvelopeFamily, FixedMapping
from context_error_mapping_support import Size

struct Delimited(Semigroup):
    comptime Value = String
    @staticmethod
    def combine(var left: String, var right: String) -> String:
        return left + "|" + right

def validation() raises:
    comptime I = ValidationFamily[StringMonoid]
    def mapped(var error: String) -> String: return "mapped:" + error
    def add(var left: Int, var right: Int) -> Int: return left + right
    var retained = pipeline[I](I.fail[Int](String("a"))).map_err(mapped)
    comptime assert type_of(retained).I == I
    assert_equal(retained^.map2(I.fail[Int](String("b")), add).get()._err().value, "mapped:ab")
    comptime Other = ValidationFamily[Delimited]
    var changed_policy = pipeline[I](I.fail[Int](String("a"))).map_err[Target=Other](mapped)
    comptime assert type_of(changed_policy).I == Other
    assert_equal(changed_policy^.map2(Other.fail[Int](String("b")), add).get()._err().value, "mapped:a|b")
    comptime Lists = ValidationFamily[ListMonoid[String]]
    def listed(var error: String) -> List[String]: return [error^]
    var changed_error = pipeline[I](I.fail[Int](String("a"))).map_err[Target=Lists](listed)
    comptime assert type_of(changed_error).I == Lists
    assert_equal(changed_error^.map2(Lists.fail[Int](List[String](["b"])), add).get()._err().value, List[String](["a", "b"]))
    def show(var value: Int) -> String: return String(value)
    def concatenate(var left: String, var right: String) -> String: return left + right
    var both = pipeline[I](I.fail[Int](String("a"))).map_both[Target=Other](show, mapped)
    comptime assert type_of(both).I == Other
    assert_equal(both^.map2(Other.fail[String](String("b")), concatenate).get()._err().value, "mapped:a|b")
    var kept = pipeline[I](I.pure(4)).map_both(show, mapped)
    comptime assert type_of(kept).I == I
    assert_equal(kept^.get()._ok().value, "4")

def custom() raises:
    def prefix(var error: String) -> String: return "fixed:" + error
    var fixed = pipeline[FixedMapping](Result[Int,String](Err(String("old")))).map_err(prefix)
    comptime assert type_of(fixed).I == FixedMapping
    assert_equal(fixed^.get()._err().value,"fixed:old")
    comptime I = MappingOnly[String]
    comptime assert conforms_to(I, ErrorMapping)
    comptime assert not conforms_to(I, ErrorRecovery)
    def size(var error: String) -> Int: return error.byte_length()
    var selected = pipeline[I](Result[Int,String](Err(String("custom")))).map_err(size)
    comptime assert type_of(selected).I == MappingOnly[Int]
    assert_equal(selected^.get()._err().value, 6)
    def show(var value: Int) -> String: return String(value)
    var both = pipeline[I](Result[Int,String](Ok(8))).map_both(show,size)
    comptime assert type_of(both).I == MappingOnly[Int]
    assert_equal(both^.get()._ok().value,"8")
    comptime assert not MapErrContract[MappingOnly[String,False,False],Result[Int,String],Size].OperationCompatible
    var calls = 0
    def counted(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    var code = 0
    try: _ = pipeline[MappingOnly[String,True]](Result[Int,String](Err(String("custom")))).map_err(counted).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 763)
    assert_equal(calls, 0)
    try: _ = pipeline[MappingOnly[String,True]](Result[Int,String](Ok(1))).map_both(show,counted).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 763)
    assert_equal(calls, 0)

def non_result() raises:
    comptime I = EnvelopeFamily[String]
    def show(var value: Int) -> String: return String(value)
    def size(var error: String) -> Int: return error.byte_length()
    var mapped = pipeline[I](Envelope(Result[Int,String](Ok(12)))).map_both[Target=EnvelopeFamily[Int]](show,size)
    comptime assert type_of(mapped).I == EnvelopeFamily[Int]
    var continued = mapped^.map(size).get()
    comptime assert type_of(continued) == Envelope[Int,Int]
    assert_equal(continued.value._ok().value,2)
    var failed = pipeline[I](Envelope(Result[Int,String](Err(String("old"))))).map_err(Size()).get()
    comptime assert type_of(failed) == Envelope[Int,Int]
    assert_equal(failed.value._err().value,3)

def main() raises:
    validation()
    custom()
    non_result()
