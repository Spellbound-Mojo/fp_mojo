"""Selected read signatures preserve native effects, pointer ABI and reuse."""
from fp.callables import BorrowSignature, BorrowCallable
from fp.functions import pipeline
from fp.iteration import iterated
from fp.data import Result, Err
from fp.effects import Reader, asks, run
from std.memory import ArcPointer
from std.builtin.rebind import rebind
from std.testing import assert_equal, assert_true

def below(value: Int) -> Bool: return value < 4
def above(value: Int) -> Bool: return value > 4
def render(value: Int) -> String: return String(value)
def size(value: String) -> Int: return value.byte_length()
def decorate(value: String) -> String: return value + "!"
def ignore(value: Int): pass
def no_error(value: Int) raises Never: pass
def failure(value: Int) raises Int: raise value
def explicit_none(value: Int) -> NoneType: return None
def fail_number(value: Int) raises Int -> Int: raise value
def fail_render(value: Int) raises Int -> String: raise value
def fail_size(value: String) raises Int -> Int: raise value.byte_length()
def fail_decorate(value: String) raises Int -> String: raise value.byte_length()
def ignore_text(value: String): pass
def fail_text(value: String) raises Int: raise value.byte_length()

def never_below(value: Int) raises Never -> Bool: return value < 4
def never_render(value: Int) raises Never -> String: return String(value)
def never_size(value: String) raises Never -> Int: return value.byte_length()
def never_decorate(value: String) raises Never -> String: return value + "!"
def never_ignore_text(value: String) raises Never: pass
comptime AliasedPure0 = def(Int) thin -> Bool
comptime AliasedPure1 = def(Int) thin -> String
comptime AliasedPure2 = def(String) thin -> Int
comptime AliasedPure3 = def(String) thin -> String
comptime AliasedPure4 = def(Int) thin
comptime AliasedPure5 = def(String) thin
comptime AliasedNever0 = def(Int) raises Never thin -> Bool
comptime AliasedNever1 = def(Int) raises Never thin -> String
comptime AliasedNever2 = def(String) raises Never thin -> Int
comptime AliasedNever3 = def(String) raises Never thin -> String
comptime AliasedNever4 = def(Int) raises Never thin
comptime AliasedNever5 = def(String) raises Never thin
comptime AliasedTyped0 = def(Int) raises Int thin -> Int
comptime AliasedTyped1 = def(Int) raises Int thin -> String
comptime AliasedTyped2 = def(String) raises Int thin -> Int
comptime AliasedTyped3 = def(String) raises Int thin -> String
comptime AliasedTyped4 = def(Int) raises Int thin
comptime AliasedTyped5 = def(String) raises Int thin

def error_code[F: BorrowCallable](function: F, ref payload: F.Payload) raises -> Int where F.Failure == Int:
    try: _ = function.invoke(payload)
    except error: return rebind[Int](error)
    return 0

def values() raises:
    var offset = 7
    def rr(value: Int) {offset} -> Int: return value + offset
    def rm(value: Int) {offset} -> String: return String(value + offset)
    def mr(value: String) {offset} -> Int: return value.byte_length() + offset
    def mm(value: String) {offset} -> String: return value + String(offset)
    var number = 2
    var text = String("ab")
    assert_equal(BorrowSignature[Int, Int].capture(rr).invoke(number), 9)
    assert_equal(BorrowSignature[Int, String].capture(rm).invoke(number), "9")
    assert_equal(BorrowSignature[String, Int].capture(mr).invoke(text), 9)
    assert_equal(BorrowSignature[String, String].capture(mm).invoke(text), "ab7")
    assert_equal(number, 2)
    assert_equal(text, "ab")
    var limit = 4
    def selected(value: Int) {limit} -> Bool: return value < limit
    var predicate = BorrowSignature[Int, Bool].capture(selected)
    comptime assert conforms_to(type_of(predicate), BorrowCallable)
    assert_equal(iterated(range(6)).filter(predicate).collect_list(), [0, 1, 2, 3])
    assert_equal(pipeline[Int]([2, 4, 1]).filter(predicate).get(), [2, 1])
    assert_true(predicate.invoke(number))
    var projected = asks[Reader[String]](BorrowSignature[String, Int].capture(size))
    assert_equal(run[Reader[String]](projected^, text), 2)

def pointers() raises:
    var number = 2
    var text = String("abc")
    var rr: def(Int) thin -> Bool = below
    var saved = BorrowSignature[Int, Bool].capture(rr)
    rr = above
    assert_true(saved.invoke(number))
    assert_equal(BorrowSignature[Int, Bool].capture(rr).invoke(number), False)
    assert_true(saved.copy().invoke(number))
    assert_true(saved.function()(number))
    var extracted = saved^.into_function()
    assert_true(extracted(number))
    var rm: def(Int) thin -> String = render
    var mr: def(String) thin -> Int = size
    var mm: def(String) thin -> String = decorate
    assert_equal(BorrowSignature[Int, String].capture(rm).invoke(number), "2")
    assert_equal(BorrowSignature[String, Int].capture(mr).invoke(text), 3)
    assert_equal(BorrowSignature[String, String].capture(mm).invoke(text), "abc!")
    var void: def(Int) thin = ignore
    BorrowSignature[Int, type_of(None)].capture(void).invoke(number)
    var never: def(Int) raises Never thin = no_error
    var impossible = BorrowSignature[Int, type_of(None)].capture(never)
    comptime assert type_of(impossible).raising
    impossible.invoke(number)
    var raising: def(Int) raises Int thin = failure
    var observed = 0
    try: BorrowSignature[Int, type_of(None), Int].capture(raising).invoke(number)
    except error: observed = error
    assert_equal(observed, 2)
    var unit = BorrowSignature[Int, NoneType].capture(explicit_none)
    comptime assert type_of(unit).Result == NoneType
    _ = unit.invoke(number)
    var err_rr: def(Int) raises Int thin -> Int = fail_number
    var err_rm: def(Int) raises Int thin -> String = fail_render
    var err_mr: def(String) raises Int thin -> Int = fail_size
    var err_mm: def(String) raises Int thin -> String = fail_decorate
    assert_equal(error_code(BorrowSignature[Int, Int, Int].capture(err_rr), number), 2)
    assert_equal(error_code(BorrowSignature[Int, String, Int].capture(err_rm), number), 2)
    assert_equal(error_code(BorrowSignature[String, Int, Int].capture(err_mr), text), 3)
    assert_equal(error_code(BorrowSignature[String, String, Int].capture(err_mm), text), 3)
    var mem_void: def(String) thin = ignore_text
    BorrowSignature[String, type_of(None)].capture(mem_void).invoke(text)
    var mem_error: def(String) raises Int thin = fail_text
    assert_equal(error_code(BorrowSignature[String, type_of(None), Int].capture(mem_error), text), 3)

def effects() raises:
    var offset = 3
    def raising(value: Int) raises Int {offset} -> Int: raise value + offset
    var callback = BorrowSignature[Int, Int, Int].capture(raising)
    comptime assert type_of(callback).Failure == Int
    var value = 2
    var observed = 0
    try: _ = callback.invoke(value)
    except error: observed = error
    assert_equal(observed, 5)
    def never(value: Int) raises Never {offset} -> Int: return value + offset
    var impossible = BorrowSignature[Int, Int].capture(never)
    comptime assert type_of(impossible).raising
    assert_equal(impossible.invoke(value), 5)
    var total = ArcPointer(0)
    def observe(value: Int) {total}: total[] += value
    var observer = BorrowSignature[Int, type_of(None)].capture(observe)
    _ = Result[String, Int](Err(2)).tap_err(observer)
    _ = pipeline(Result[String, Int](Err(3))).tap_err(observer).get()
    assert_equal(total[], 5)
    assert_equal(iterated(range(3)).tap_each(observer^).collect_list(), [0, 1, 2])
    assert_equal(total[], 8)

def aliases() raises:
    var number = 2
    var text = String("abc")
    var p_pure_0: AliasedPure0 = below
    var f_pure_0 = BorrowSignature[Int, Bool].capture(p_pure_0)
    comptime assert type_of(f_pure_0).F == AliasedPure0
    assert_equal(f_pure_0.invoke(number), True)
    var p_pure_1: AliasedPure1 = render
    var f_pure_1 = BorrowSignature[Int, String].capture(p_pure_1)
    comptime assert type_of(f_pure_1).F == AliasedPure1
    assert_equal(f_pure_1.invoke(number), "2")
    var p_pure_2: AliasedPure2 = size
    var f_pure_2 = BorrowSignature[String, Int].capture(p_pure_2)
    comptime assert type_of(f_pure_2).F == AliasedPure2
    assert_equal(f_pure_2.invoke(text), 3)
    var p_pure_3: AliasedPure3 = decorate
    var f_pure_3 = BorrowSignature[String, String].capture(p_pure_3)
    comptime assert type_of(f_pure_3).F == AliasedPure3
    assert_equal(f_pure_3.invoke(text), "abc!")
    var p_pure_4: AliasedPure4 = ignore
    var f_pure_4 = BorrowSignature[Int, type_of(None)].capture(p_pure_4)
    comptime assert type_of(f_pure_4).F == AliasedPure4
    f_pure_4.invoke(number)
    var p_pure_5: AliasedPure5 = ignore_text
    var f_pure_5 = BorrowSignature[String, type_of(None)].capture(p_pure_5)
    comptime assert type_of(f_pure_5).F == AliasedPure5
    f_pure_5.invoke(text)
    var p_never_0: AliasedNever0 = never_below
    var f_never_0 = BorrowSignature[Int, Bool].capture(p_never_0)
    comptime assert type_of(f_never_0).F == AliasedNever0
    comptime assert type_of(f_never_0).raising
    assert_equal(f_never_0.invoke(number), True)
    var p_never_1: AliasedNever1 = never_render
    var f_never_1 = BorrowSignature[Int, String].capture(p_never_1)
    comptime assert type_of(f_never_1).F == AliasedNever1
    comptime assert type_of(f_never_1).raising
    assert_equal(f_never_1.invoke(number), "2")
    var p_never_2: AliasedNever2 = never_size
    var f_never_2 = BorrowSignature[String, Int].capture(p_never_2)
    comptime assert type_of(f_never_2).F == AliasedNever2
    comptime assert type_of(f_never_2).raising
    assert_equal(f_never_2.invoke(text), 3)
    var p_never_3: AliasedNever3 = never_decorate
    var f_never_3 = BorrowSignature[String, String].capture(p_never_3)
    comptime assert type_of(f_never_3).F == AliasedNever3
    comptime assert type_of(f_never_3).raising
    assert_equal(f_never_3.invoke(text), "abc!")
    var p_never_4: AliasedNever4 = no_error
    var f_never_4 = BorrowSignature[Int, type_of(None)].capture(p_never_4)
    comptime assert type_of(f_never_4).F == AliasedNever4
    comptime assert type_of(f_never_4).raising
    f_never_4.invoke(number)
    var p_never_5: AliasedNever5 = never_ignore_text
    var f_never_5 = BorrowSignature[String, type_of(None)].capture(p_never_5)
    comptime assert type_of(f_never_5).F == AliasedNever5
    comptime assert type_of(f_never_5).raising
    f_never_5.invoke(text)
    var p_typed_0: AliasedTyped0 = fail_number
    var f_typed_0 = BorrowSignature[Int, Int, Int].capture(p_typed_0)
    comptime assert type_of(f_typed_0).F == AliasedTyped0
    comptime assert type_of(f_typed_0).raising
    assert_equal(error_code(f_typed_0, number), 2)
    var p_typed_1: AliasedTyped1 = fail_render
    var f_typed_1 = BorrowSignature[Int, String, Int].capture(p_typed_1)
    comptime assert type_of(f_typed_1).F == AliasedTyped1
    comptime assert type_of(f_typed_1).raising
    assert_equal(error_code(f_typed_1, number), 2)
    var p_typed_2: AliasedTyped2 = fail_size
    var f_typed_2 = BorrowSignature[String, Int, Int].capture(p_typed_2)
    comptime assert type_of(f_typed_2).F == AliasedTyped2
    comptime assert type_of(f_typed_2).raising
    assert_equal(error_code(f_typed_2, text), 3)
    var p_typed_3: AliasedTyped3 = fail_decorate
    var f_typed_3 = BorrowSignature[String, String, Int].capture(p_typed_3)
    comptime assert type_of(f_typed_3).F == AliasedTyped3
    comptime assert type_of(f_typed_3).raising
    assert_equal(error_code(f_typed_3, text), 3)
    var p_typed_4: AliasedTyped4 = failure
    var f_typed_4 = BorrowSignature[Int, type_of(None), Int].capture(p_typed_4)
    comptime assert type_of(f_typed_4).F == AliasedTyped4
    comptime assert type_of(f_typed_4).raising
    assert_equal(error_code(f_typed_4, number), 2)
    var p_typed_5: AliasedTyped5 = fail_text
    var f_typed_5 = BorrowSignature[String, type_of(None), Int].capture(p_typed_5)
    comptime assert type_of(f_typed_5).F == AliasedTyped5
    comptime assert type_of(f_typed_5).raising
    assert_equal(error_code(f_typed_5, text), 3)

def main() raises:
    values()
    pointers()
    aliases()
    effects()
