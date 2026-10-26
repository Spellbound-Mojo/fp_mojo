from fp.data import Capture, Result
from std.testing import assert_equal
from std.os import abort
@fieldwise_init
struct Fault(Movable):
    var code: Int
def callback_z() -> Int:
    return 3
def callback_k(var **kwargs: Int) -> Int:
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_r(a: Int) -> Int:
    if a != 1: abort("argument changed")
    return 3
def callback_rk(a: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_m(mut a: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    return 3
def callback_mk(mut a: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_o(var a: Int) -> Int:
    if a != 1: abort("argument changed")
    return 3
def callback_ok(var a: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_rr(a: Int, b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    return 3
def callback_rrk(a: Int, b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_rm(a: Int, mut b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    return 3
def callback_rmk(a: Int, mut b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_ro(a: Int, var b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    return 3
def callback_rok(a: Int, var b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_mr(mut a: Int, b: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    return 3
def callback_mrk(mut a: Int, b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_mm(mut a: Int, mut b: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    b += 1
    return 3
def callback_mmk(mut a: Int, mut b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_mo(mut a: Int, var b: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    return 3
def callback_mok(mut a: Int, var b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    a += 1
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_or(var a: Int, b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    return 3
def callback_ork(var a: Int, b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_om(var a: Int, mut b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    return 3
def callback_omk(var a: Int, mut b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def callback_oo(var a: Int, var b: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    return 3
def callback_ook(var a: Int, var b: Int, /, var **kwargs: Int) -> Int:
    if a != 1: abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    return 3
def main() raises:
    var f_z: def() thin -> Int = callback_z
    var result_z = Capture().run(f_z)
    comptime assert type_of(result_z) == Result[Int, Never]
    assert_equal(result_z._ok().value, 3)
    var f_k: def(var **kwargs: Int) thin -> Int = callback_k
    var result_k = Capture.kwargs(value=1).run(f_k)
    comptime assert type_of(result_k) == Result[Int, Never]
    assert_equal(result_k._ok().value, 3)
    var f_r: def(Int) thin -> Int = callback_r
    var a_r = 1
    var result_r = Capture.borrow(a_r).run(f_r)
    comptime assert type_of(result_r) == Result[Int, Never]
    assert_equal(result_r._ok().value, 3)
    var f_rk: def(Int, /, var **kwargs: Int) thin -> Int = callback_rk
    var a_rk = 1
    var result_rk = Capture.borrow(a_rk).kwargs(value=1).run(f_rk)
    comptime assert type_of(result_rk) == Result[Int, Never]
    assert_equal(result_rk._ok().value, 3)
    var f_m: def(mut Int) thin -> Int = callback_m
    var a_m = 1
    var result_m = Capture.mutable(a_m).run(f_m)
    comptime assert type_of(result_m) == Result[Int, Never]
    assert_equal(result_m._ok().value, 3)
    assert_equal(a_m, 2)
    var f_mk: def(mut Int, /, var **kwargs: Int) thin -> Int = callback_mk
    var a_mk = 1
    var result_mk = Capture.mutable(a_mk).kwargs(value=1).run(f_mk)
    comptime assert type_of(result_mk) == Result[Int, Never]
    assert_equal(result_mk._ok().value, 3)
    assert_equal(a_mk, 2)
    var f_o: def(var Int) thin -> Int = callback_o
    var a_o = 1
    var result_o = Capture.take(a_o).run(f_o)
    comptime assert type_of(result_o) == Result[Int, Never]
    assert_equal(result_o._ok().value, 3)
    var f_ok: def(var Int, /, var **kwargs: Int) thin -> Int = callback_ok
    var a_ok = 1
    var result_ok = Capture.take(a_ok).kwargs(value=1).run(f_ok)
    comptime assert type_of(result_ok) == Result[Int, Never]
    assert_equal(result_ok._ok().value, 3)
    var f_rr: def(Int, Int) thin -> Int = callback_rr
    var a_rr = 1
    var b_rr = 1
    var result_rr = Capture.borrow(a_rr).borrow(b_rr).run(f_rr)
    comptime assert type_of(result_rr) == Result[Int, Never]
    assert_equal(result_rr._ok().value, 3)
    var f_rrk: def(Int, Int, /, var **kwargs: Int) thin -> Int = callback_rrk
    var a_rrk = 1
    var b_rrk = 1
    var result_rrk = Capture.borrow(a_rrk).borrow(b_rrk).kwargs(value=1).run(f_rrk)
    comptime assert type_of(result_rrk) == Result[Int, Never]
    assert_equal(result_rrk._ok().value, 3)
    var f_rm: def(Int, mut Int) thin -> Int = callback_rm
    var a_rm = 1
    var b_rm = 1
    var result_rm = Capture.borrow(a_rm).mutable(b_rm).run(f_rm)
    comptime assert type_of(result_rm) == Result[Int, Never]
    assert_equal(result_rm._ok().value, 3)
    assert_equal(b_rm, 2)
    var f_rmk: def(Int, mut Int, /, var **kwargs: Int) thin -> Int = callback_rmk
    var a_rmk = 1
    var b_rmk = 1
    var result_rmk = Capture.borrow(a_rmk).mutable(b_rmk).kwargs(value=1).run(f_rmk)
    comptime assert type_of(result_rmk) == Result[Int, Never]
    assert_equal(result_rmk._ok().value, 3)
    assert_equal(b_rmk, 2)
    var f_ro: def(Int, var Int) thin -> Int = callback_ro
    var a_ro = 1
    var b_ro = 1
    var result_ro = Capture.borrow(a_ro).take(b_ro).run(f_ro)
    comptime assert type_of(result_ro) == Result[Int, Never]
    assert_equal(result_ro._ok().value, 3)
    var f_rok: def(Int, var Int, /, var **kwargs: Int) thin -> Int = callback_rok
    var a_rok = 1
    var b_rok = 1
    var result_rok = Capture.borrow(a_rok).take(b_rok).kwargs(value=1).run(f_rok)
    comptime assert type_of(result_rok) == Result[Int, Never]
    assert_equal(result_rok._ok().value, 3)
    var f_mr: def(mut Int, Int) thin -> Int = callback_mr
    var a_mr = 1
    var b_mr = 1
    var result_mr = Capture.mutable(a_mr).borrow(b_mr).run(f_mr)
    comptime assert type_of(result_mr) == Result[Int, Never]
    assert_equal(result_mr._ok().value, 3)
    assert_equal(a_mr, 2)
    var f_mrk: def(mut Int, Int, /, var **kwargs: Int) thin -> Int = callback_mrk
    var a_mrk = 1
    var b_mrk = 1
    var result_mrk = Capture.mutable(a_mrk).borrow(b_mrk).kwargs(value=1).run(f_mrk)
    comptime assert type_of(result_mrk) == Result[Int, Never]
    assert_equal(result_mrk._ok().value, 3)
    assert_equal(a_mrk, 2)
    var f_mm: def(mut Int, mut Int) thin -> Int = callback_mm
    var a_mm = 1
    var b_mm = 1
    var result_mm = Capture.mutable(a_mm).mutable(b_mm).run(f_mm)
    comptime assert type_of(result_mm) == Result[Int, Never]
    assert_equal(result_mm._ok().value, 3)
    assert_equal(a_mm, 2)
    assert_equal(b_mm, 2)
    var f_mmk: def(mut Int, mut Int, /, var **kwargs: Int) thin -> Int = callback_mmk
    var a_mmk = 1
    var b_mmk = 1
    var result_mmk = Capture.mutable(a_mmk).mutable(b_mmk).kwargs(value=1).run(f_mmk)
    comptime assert type_of(result_mmk) == Result[Int, Never]
    assert_equal(result_mmk._ok().value, 3)
    assert_equal(a_mmk, 2)
    assert_equal(b_mmk, 2)
    var f_mo: def(mut Int, var Int) thin -> Int = callback_mo
    var a_mo = 1
    var b_mo = 1
    var result_mo = Capture.mutable(a_mo).take(b_mo).run(f_mo)
    comptime assert type_of(result_mo) == Result[Int, Never]
    assert_equal(result_mo._ok().value, 3)
    assert_equal(a_mo, 2)
    var f_mok: def(mut Int, var Int, /, var **kwargs: Int) thin -> Int = callback_mok
    var a_mok = 1
    var b_mok = 1
    var result_mok = Capture.mutable(a_mok).take(b_mok).kwargs(value=1).run(f_mok)
    comptime assert type_of(result_mok) == Result[Int, Never]
    assert_equal(result_mok._ok().value, 3)
    assert_equal(a_mok, 2)
    var f_or: def(var Int, Int) thin -> Int = callback_or
    var a_or = 1
    var b_or = 1
    var result_or = Capture.take(a_or).borrow(b_or).run(f_or)
    comptime assert type_of(result_or) == Result[Int, Never]
    assert_equal(result_or._ok().value, 3)
    var f_ork: def(var Int, Int, /, var **kwargs: Int) thin -> Int = callback_ork
    var a_ork = 1
    var b_ork = 1
    var result_ork = Capture.take(a_ork).borrow(b_ork).kwargs(value=1).run(f_ork)
    comptime assert type_of(result_ork) == Result[Int, Never]
    assert_equal(result_ork._ok().value, 3)
    var f_om: def(var Int, mut Int) thin -> Int = callback_om
    var a_om = 1
    var b_om = 1
    var result_om = Capture.take(a_om).mutable(b_om).run(f_om)
    comptime assert type_of(result_om) == Result[Int, Never]
    assert_equal(result_om._ok().value, 3)
    assert_equal(b_om, 2)
    var f_omk: def(var Int, mut Int, /, var **kwargs: Int) thin -> Int = callback_omk
    var a_omk = 1
    var b_omk = 1
    var result_omk = Capture.take(a_omk).mutable(b_omk).kwargs(value=1).run(f_omk)
    comptime assert type_of(result_omk) == Result[Int, Never]
    assert_equal(result_omk._ok().value, 3)
    assert_equal(b_omk, 2)
    var f_oo: def(var Int, var Int) thin -> Int = callback_oo
    var a_oo = 1
    var b_oo = 1
    var result_oo = Capture.take(a_oo).take(b_oo).run(f_oo)
    comptime assert type_of(result_oo) == Result[Int, Never]
    assert_equal(result_oo._ok().value, 3)
    var f_ook: def(var Int, var Int, /, var **kwargs: Int) thin -> Int = callback_ook
    var a_ook = 1
    var b_ook = 1
    var result_ook = Capture.take(a_ook).take(b_ook).kwargs(value=1).run(f_ook)
    comptime assert type_of(result_ook) == Result[Int, Never]
    assert_equal(result_ook._ok().value, 3)
