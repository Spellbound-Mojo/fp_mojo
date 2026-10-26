from fp.data import Capture, Result
from std.testing import assert_equal
from std.os import abort
@fieldwise_init
struct Fault(Movable):
    var code: Int
def callback_z():
    pass
def callback_k(var **kwargs: Int):
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_r(a: String):
    if a != "start": abort("argument changed")
    pass
def callback_rk(a: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_m(mut a: String):
    if a != "start": abort("argument changed")
    a += "!"
    pass
def callback_mk(mut a: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    a += "!"
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_o(var a: String):
    if a != "start": abort("argument changed")
    pass
def callback_ok(var a: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_rr(a: String, b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    pass
def callback_rrk(a: String, b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_rm(a: String, mut b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    b += "!"
    pass
def callback_rmk(a: String, mut b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    b += "!"
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_ro(a: String, var b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    pass
def callback_rok(a: String, var b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_mr(mut a: String, b: String):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    pass
def callback_mrk(mut a: String, b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_mm(mut a: String, mut b: String):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    b += "!"
    pass
def callback_mmk(mut a: String, mut b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    b += "!"
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_mo(mut a: String, var b: String):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    pass
def callback_mok(mut a: String, var b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    a += "!"
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_or(var a: String, b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    pass
def callback_ork(var a: String, b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_om(var a: String, mut b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    b += "!"
    pass
def callback_omk(var a: String, mut b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    b += "!"
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def callback_oo(var a: String, var b: String):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    pass
def callback_ook(var a: String, var b: String, /, var **kwargs: Int):
    if a != "start": abort("argument changed")
    if b != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    pass
def main() raises:
    var f_z: def() thin = callback_z
    var result_z = Capture().run(f_z)
    comptime assert type_of(result_z) == Result[type_of(None), Never]
    assert_equal(result_z.is_ok(), True)
    var f_k: def(var **kwargs: Int) thin = callback_k
    var result_k = Capture.kwargs(value=1).run(f_k)
    comptime assert type_of(result_k) == Result[type_of(None), Never]
    assert_equal(result_k.is_ok(), True)
    var f_r: def(String) thin = callback_r
    var a_r = String("start")
    var result_r = Capture.borrow(a_r).run(f_r)
    comptime assert type_of(result_r) == Result[type_of(None), Never]
    assert_equal(result_r.is_ok(), True)
    var f_rk: def(String, /, var **kwargs: Int) thin = callback_rk
    var a_rk = String("start")
    var result_rk = Capture.borrow(a_rk).kwargs(value=1).run(f_rk)
    comptime assert type_of(result_rk) == Result[type_of(None), Never]
    assert_equal(result_rk.is_ok(), True)
    var f_m: def(mut String) thin = callback_m
    var a_m = String("start")
    var result_m = Capture.mutable(a_m).run(f_m)
    comptime assert type_of(result_m) == Result[type_of(None), Never]
    assert_equal(result_m.is_ok(), True)
    assert_equal(a_m, "start!")
    var f_mk: def(mut String, /, var **kwargs: Int) thin = callback_mk
    var a_mk = String("start")
    var result_mk = Capture.mutable(a_mk).kwargs(value=1).run(f_mk)
    comptime assert type_of(result_mk) == Result[type_of(None), Never]
    assert_equal(result_mk.is_ok(), True)
    assert_equal(a_mk, "start!")
    var f_o: def(var String) thin = callback_o
    var a_o = String("start")
    var result_o = Capture.take(a_o^).run(f_o)
    comptime assert type_of(result_o) == Result[type_of(None), Never]
    assert_equal(result_o.is_ok(), True)
    var f_ok: def(var String, /, var **kwargs: Int) thin = callback_ok
    var a_ok = String("start")
    var result_ok = Capture.take(a_ok^).kwargs(value=1).run(f_ok)
    comptime assert type_of(result_ok) == Result[type_of(None), Never]
    assert_equal(result_ok.is_ok(), True)
    var f_rr: def(String, String) thin = callback_rr
    var a_rr = String("start")
    var b_rr = String("start")
    var result_rr = Capture.borrow(a_rr).borrow(b_rr).run(f_rr)
    comptime assert type_of(result_rr) == Result[type_of(None), Never]
    assert_equal(result_rr.is_ok(), True)
    var f_rrk: def(String, String, /, var **kwargs: Int) thin = callback_rrk
    var a_rrk = String("start")
    var b_rrk = String("start")
    var result_rrk = Capture.borrow(a_rrk).borrow(b_rrk).kwargs(value=1).run(f_rrk)
    comptime assert type_of(result_rrk) == Result[type_of(None), Never]
    assert_equal(result_rrk.is_ok(), True)
    var f_rm: def(String, mut String) thin = callback_rm
    var a_rm = String("start")
    var b_rm = String("start")
    var result_rm = Capture.borrow(a_rm).mutable(b_rm).run(f_rm)
    comptime assert type_of(result_rm) == Result[type_of(None), Never]
    assert_equal(result_rm.is_ok(), True)
    assert_equal(b_rm, "start!")
    var f_rmk: def(String, mut String, /, var **kwargs: Int) thin = callback_rmk
    var a_rmk = String("start")
    var b_rmk = String("start")
    var result_rmk = Capture.borrow(a_rmk).mutable(b_rmk).kwargs(value=1).run(f_rmk)
    comptime assert type_of(result_rmk) == Result[type_of(None), Never]
    assert_equal(result_rmk.is_ok(), True)
    assert_equal(b_rmk, "start!")
    var f_ro: def(String, var String) thin = callback_ro
    var a_ro = String("start")
    var b_ro = String("start")
    var result_ro = Capture.borrow(a_ro).take(b_ro^).run(f_ro)
    comptime assert type_of(result_ro) == Result[type_of(None), Never]
    assert_equal(result_ro.is_ok(), True)
    var f_rok: def(String, var String, /, var **kwargs: Int) thin = callback_rok
    var a_rok = String("start")
    var b_rok = String("start")
    var result_rok = Capture.borrow(a_rok).take(b_rok^).kwargs(value=1).run(f_rok)
    comptime assert type_of(result_rok) == Result[type_of(None), Never]
    assert_equal(result_rok.is_ok(), True)
    var f_mr: def(mut String, String) thin = callback_mr
    var a_mr = String("start")
    var b_mr = String("start")
    var result_mr = Capture.mutable(a_mr).borrow(b_mr).run(f_mr)
    comptime assert type_of(result_mr) == Result[type_of(None), Never]
    assert_equal(result_mr.is_ok(), True)
    assert_equal(a_mr, "start!")
    var f_mrk: def(mut String, String, /, var **kwargs: Int) thin = callback_mrk
    var a_mrk = String("start")
    var b_mrk = String("start")
    var result_mrk = Capture.mutable(a_mrk).borrow(b_mrk).kwargs(value=1).run(f_mrk)
    comptime assert type_of(result_mrk) == Result[type_of(None), Never]
    assert_equal(result_mrk.is_ok(), True)
    assert_equal(a_mrk, "start!")
    var f_mm: def(mut String, mut String) thin = callback_mm
    var a_mm = String("start")
    var b_mm = String("start")
    var result_mm = Capture.mutable(a_mm).mutable(b_mm).run(f_mm)
    comptime assert type_of(result_mm) == Result[type_of(None), Never]
    assert_equal(result_mm.is_ok(), True)
    assert_equal(a_mm, "start!")
    assert_equal(b_mm, "start!")
    var f_mmk: def(mut String, mut String, /, var **kwargs: Int) thin = callback_mmk
    var a_mmk = String("start")
    var b_mmk = String("start")
    var result_mmk = Capture.mutable(a_mmk).mutable(b_mmk).kwargs(value=1).run(f_mmk)
    comptime assert type_of(result_mmk) == Result[type_of(None), Never]
    assert_equal(result_mmk.is_ok(), True)
    assert_equal(a_mmk, "start!")
    assert_equal(b_mmk, "start!")
    var f_mo: def(mut String, var String) thin = callback_mo
    var a_mo = String("start")
    var b_mo = String("start")
    var result_mo = Capture.mutable(a_mo).take(b_mo^).run(f_mo)
    comptime assert type_of(result_mo) == Result[type_of(None), Never]
    assert_equal(result_mo.is_ok(), True)
    assert_equal(a_mo, "start!")
    var f_mok: def(mut String, var String, /, var **kwargs: Int) thin = callback_mok
    var a_mok = String("start")
    var b_mok = String("start")
    var result_mok = Capture.mutable(a_mok).take(b_mok^).kwargs(value=1).run(f_mok)
    comptime assert type_of(result_mok) == Result[type_of(None), Never]
    assert_equal(result_mok.is_ok(), True)
    assert_equal(a_mok, "start!")
    var f_or: def(var String, String) thin = callback_or
    var a_or = String("start")
    var b_or = String("start")
    var result_or = Capture.take(a_or^).borrow(b_or).run(f_or)
    comptime assert type_of(result_or) == Result[type_of(None), Never]
    assert_equal(result_or.is_ok(), True)
    var f_ork: def(var String, String, /, var **kwargs: Int) thin = callback_ork
    var a_ork = String("start")
    var b_ork = String("start")
    var result_ork = Capture.take(a_ork^).borrow(b_ork).kwargs(value=1).run(f_ork)
    comptime assert type_of(result_ork) == Result[type_of(None), Never]
    assert_equal(result_ork.is_ok(), True)
    var f_om: def(var String, mut String) thin = callback_om
    var a_om = String("start")
    var b_om = String("start")
    var result_om = Capture.take(a_om^).mutable(b_om).run(f_om)
    comptime assert type_of(result_om) == Result[type_of(None), Never]
    assert_equal(result_om.is_ok(), True)
    assert_equal(b_om, "start!")
    var f_omk: def(var String, mut String, /, var **kwargs: Int) thin = callback_omk
    var a_omk = String("start")
    var b_omk = String("start")
    var result_omk = Capture.take(a_omk^).mutable(b_omk).kwargs(value=1).run(f_omk)
    comptime assert type_of(result_omk) == Result[type_of(None), Never]
    assert_equal(result_omk.is_ok(), True)
    assert_equal(b_omk, "start!")
    var f_oo: def(var String, var String) thin = callback_oo
    var a_oo = String("start")
    var b_oo = String("start")
    var result_oo = Capture.take(a_oo^).take(b_oo^).run(f_oo)
    comptime assert type_of(result_oo) == Result[type_of(None), Never]
    assert_equal(result_oo.is_ok(), True)
    var f_ook: def(var String, var String, /, var **kwargs: Int) thin = callback_ook
    var a_ook = String("start")
    var b_ook = String("start")
    var result_ook = Capture.take(a_ook^).take(b_ook^).kwargs(value=1).run(f_ook)
    comptime assert type_of(result_ook) == Result[type_of(None), Never]
    assert_equal(result_ook.is_ok(), True)
