from fp.data import Capture, Result
from std.testing import assert_equal
from std.os import abort
@fieldwise_init
struct Fault(Movable):
    var code: Int
def callback_z() raises Fault:
    raise Fault(7)
def callback_k(var **kwargs: Int) raises Fault:
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_r(a: String) raises Fault:
    if a != "start": abort("argument changed")
    raise Fault(7)
def callback_rk(a: String, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_m(mut a: String) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    raise Fault(7)
def callback_mk(mut a: String, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_o(var a: String) raises Fault:
    if a != "start": abort("argument changed")
    raise Fault(7)
def callback_ok(var a: String, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_rr(a: String, b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_rrk(a: String, b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_rm(a: String, mut b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    raise Fault(7)
def callback_rmk(a: String, mut b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_ro(a: String, var b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_rok(a: String, var b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_mr(mut a: String, b: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_mrk(mut a: String, b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_mm(mut a: String, mut b: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    b += 1
    raise Fault(7)
def callback_mmk(mut a: String, mut b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_mo(mut a: String, var b: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_mok(mut a: String, var b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    a += "!"
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_or(var a: String, b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_ork(var a: String, b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_om(var a: String, mut b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    raise Fault(7)
def callback_omk(var a: String, mut b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    b += 1
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def callback_oo(var a: String, var b: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    raise Fault(7)
def callback_ook(var a: String, var b: Int, /, var **kwargs: Int) raises Fault:
    if a != "start": abort("argument changed")
    if b != 1: abort("argument changed")
    var total = 0
    for entry in kwargs.items(): total += entry.value
    if total != 1: abort("keyword changed")
    raise Fault(7)
def main() raises:
    var f_z: def() raises Fault thin = callback_z
    var result_z = Capture[Fault]().run(f_z)
    comptime assert type_of(result_z) == Result[type_of(None), Fault]
    assert_equal(result_z._err().value.code, 7)
    var f_k: def(var **kwargs: Int) raises Fault thin = callback_k
    var result_k = Capture[Fault].kwargs(value=1).run(f_k)
    comptime assert type_of(result_k) == Result[type_of(None), Fault]
    assert_equal(result_k._err().value.code, 7)
    var f_r: def(String) raises Fault thin = callback_r
    var a_r = String("start")
    var result_r = Capture[Fault].borrow(a_r).run(f_r)
    comptime assert type_of(result_r) == Result[type_of(None), Fault]
    assert_equal(result_r._err().value.code, 7)
    var f_rk: def(String, /, var **kwargs: Int) raises Fault thin = callback_rk
    var a_rk = String("start")
    var result_rk = Capture[Fault].borrow(a_rk).kwargs(value=1).run(f_rk)
    comptime assert type_of(result_rk) == Result[type_of(None), Fault]
    assert_equal(result_rk._err().value.code, 7)
    var f_m: def(mut String) raises Fault thin = callback_m
    var a_m = String("start")
    var result_m = Capture[Fault].mutable(a_m).run(f_m)
    comptime assert type_of(result_m) == Result[type_of(None), Fault]
    assert_equal(result_m._err().value.code, 7)
    assert_equal(a_m, "start!")
    var f_mk: def(mut String, /, var **kwargs: Int) raises Fault thin = callback_mk
    var a_mk = String("start")
    var result_mk = Capture[Fault].mutable(a_mk).kwargs(value=1).run(f_mk)
    comptime assert type_of(result_mk) == Result[type_of(None), Fault]
    assert_equal(result_mk._err().value.code, 7)
    assert_equal(a_mk, "start!")
    var f_o: def(var String) raises Fault thin = callback_o
    var a_o = String("start")
    var result_o = Capture[Fault].take(a_o^).run(f_o)
    comptime assert type_of(result_o) == Result[type_of(None), Fault]
    assert_equal(result_o._err().value.code, 7)
    var f_ok: def(var String, /, var **kwargs: Int) raises Fault thin = callback_ok
    var a_ok = String("start")
    var result_ok = Capture[Fault].take(a_ok^).kwargs(value=1).run(f_ok)
    comptime assert type_of(result_ok) == Result[type_of(None), Fault]
    assert_equal(result_ok._err().value.code, 7)
    var f_rr: def(String, Int) raises Fault thin = callback_rr
    var a_rr = String("start")
    var b_rr = 1
    var result_rr = Capture[Fault].borrow(a_rr).borrow(b_rr).run(f_rr)
    comptime assert type_of(result_rr) == Result[type_of(None), Fault]
    assert_equal(result_rr._err().value.code, 7)
    var f_rrk: def(String, Int, /, var **kwargs: Int) raises Fault thin = callback_rrk
    var a_rrk = String("start")
    var b_rrk = 1
    var result_rrk = Capture[Fault].borrow(a_rrk).borrow(b_rrk).kwargs(value=1).run(f_rrk)
    comptime assert type_of(result_rrk) == Result[type_of(None), Fault]
    assert_equal(result_rrk._err().value.code, 7)
    var f_rm: def(String, mut Int) raises Fault thin = callback_rm
    var a_rm = String("start")
    var b_rm = 1
    var result_rm = Capture[Fault].borrow(a_rm).mutable(b_rm).run(f_rm)
    comptime assert type_of(result_rm) == Result[type_of(None), Fault]
    assert_equal(result_rm._err().value.code, 7)
    assert_equal(b_rm, 2)
    var f_rmk: def(String, mut Int, /, var **kwargs: Int) raises Fault thin = callback_rmk
    var a_rmk = String("start")
    var b_rmk = 1
    var result_rmk = Capture[Fault].borrow(a_rmk).mutable(b_rmk).kwargs(value=1).run(f_rmk)
    comptime assert type_of(result_rmk) == Result[type_of(None), Fault]
    assert_equal(result_rmk._err().value.code, 7)
    assert_equal(b_rmk, 2)
    var f_ro: def(String, var Int) raises Fault thin = callback_ro
    var a_ro = String("start")
    var b_ro = 1
    var result_ro = Capture[Fault].borrow(a_ro).take(b_ro).run(f_ro)
    comptime assert type_of(result_ro) == Result[type_of(None), Fault]
    assert_equal(result_ro._err().value.code, 7)
    var f_rok: def(String, var Int, /, var **kwargs: Int) raises Fault thin = callback_rok
    var a_rok = String("start")
    var b_rok = 1
    var result_rok = Capture[Fault].borrow(a_rok).take(b_rok).kwargs(value=1).run(f_rok)
    comptime assert type_of(result_rok) == Result[type_of(None), Fault]
    assert_equal(result_rok._err().value.code, 7)
    var f_mr: def(mut String, Int) raises Fault thin = callback_mr
    var a_mr = String("start")
    var b_mr = 1
    var result_mr = Capture[Fault].mutable(a_mr).borrow(b_mr).run(f_mr)
    comptime assert type_of(result_mr) == Result[type_of(None), Fault]
    assert_equal(result_mr._err().value.code, 7)
    assert_equal(a_mr, "start!")
    var f_mrk: def(mut String, Int, /, var **kwargs: Int) raises Fault thin = callback_mrk
    var a_mrk = String("start")
    var b_mrk = 1
    var result_mrk = Capture[Fault].mutable(a_mrk).borrow(b_mrk).kwargs(value=1).run(f_mrk)
    comptime assert type_of(result_mrk) == Result[type_of(None), Fault]
    assert_equal(result_mrk._err().value.code, 7)
    assert_equal(a_mrk, "start!")
    var f_mm: def(mut String, mut Int) raises Fault thin = callback_mm
    var a_mm = String("start")
    var b_mm = 1
    var result_mm = Capture[Fault].mutable(a_mm).mutable(b_mm).run(f_mm)
    comptime assert type_of(result_mm) == Result[type_of(None), Fault]
    assert_equal(result_mm._err().value.code, 7)
    assert_equal(a_mm, "start!")
    assert_equal(b_mm, 2)
    var f_mmk: def(mut String, mut Int, /, var **kwargs: Int) raises Fault thin = callback_mmk
    var a_mmk = String("start")
    var b_mmk = 1
    var result_mmk = Capture[Fault].mutable(a_mmk).mutable(b_mmk).kwargs(value=1).run(f_mmk)
    comptime assert type_of(result_mmk) == Result[type_of(None), Fault]
    assert_equal(result_mmk._err().value.code, 7)
    assert_equal(a_mmk, "start!")
    assert_equal(b_mmk, 2)
    var f_mo: def(mut String, var Int) raises Fault thin = callback_mo
    var a_mo = String("start")
    var b_mo = 1
    var result_mo = Capture[Fault].mutable(a_mo).take(b_mo).run(f_mo)
    comptime assert type_of(result_mo) == Result[type_of(None), Fault]
    assert_equal(result_mo._err().value.code, 7)
    assert_equal(a_mo, "start!")
    var f_mok: def(mut String, var Int, /, var **kwargs: Int) raises Fault thin = callback_mok
    var a_mok = String("start")
    var b_mok = 1
    var result_mok = Capture[Fault].mutable(a_mok).take(b_mok).kwargs(value=1).run(f_mok)
    comptime assert type_of(result_mok) == Result[type_of(None), Fault]
    assert_equal(result_mok._err().value.code, 7)
    assert_equal(a_mok, "start!")
    var f_or: def(var String, Int) raises Fault thin = callback_or
    var a_or = String("start")
    var b_or = 1
    var result_or = Capture[Fault].take(a_or^).borrow(b_or).run(f_or)
    comptime assert type_of(result_or) == Result[type_of(None), Fault]
    assert_equal(result_or._err().value.code, 7)
    var f_ork: def(var String, Int, /, var **kwargs: Int) raises Fault thin = callback_ork
    var a_ork = String("start")
    var b_ork = 1
    var result_ork = Capture[Fault].take(a_ork^).borrow(b_ork).kwargs(value=1).run(f_ork)
    comptime assert type_of(result_ork) == Result[type_of(None), Fault]
    assert_equal(result_ork._err().value.code, 7)
    var f_om: def(var String, mut Int) raises Fault thin = callback_om
    var a_om = String("start")
    var b_om = 1
    var result_om = Capture[Fault].take(a_om^).mutable(b_om).run(f_om)
    comptime assert type_of(result_om) == Result[type_of(None), Fault]
    assert_equal(result_om._err().value.code, 7)
    assert_equal(b_om, 2)
    var f_omk: def(var String, mut Int, /, var **kwargs: Int) raises Fault thin = callback_omk
    var a_omk = String("start")
    var b_omk = 1
    var result_omk = Capture[Fault].take(a_omk^).mutable(b_omk).kwargs(value=1).run(f_omk)
    comptime assert type_of(result_omk) == Result[type_of(None), Fault]
    assert_equal(result_omk._err().value.code, 7)
    assert_equal(b_omk, 2)
    var f_oo: def(var String, var Int) raises Fault thin = callback_oo
    var a_oo = String("start")
    var b_oo = 1
    var result_oo = Capture[Fault].take(a_oo^).take(b_oo).run(f_oo)
    comptime assert type_of(result_oo) == Result[type_of(None), Fault]
    assert_equal(result_oo._err().value.code, 7)
    var f_ook: def(var String, var Int, /, var **kwargs: Int) raises Fault thin = callback_ook
    var a_ook = String("start")
    var b_ook = 1
    var result_ook = Capture[Fault].take(a_ook^).take(b_ook).kwargs(value=1).run(f_ook)
    comptime assert type_of(result_ook) == Result[type_of(None), Fault]
    assert_equal(result_ook._err().value.code, 7)
