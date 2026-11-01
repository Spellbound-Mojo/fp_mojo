"""Stored thin pointers retain register/memory arguments, results and exact errors."""
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from std.testing import assert_equal

def scalar(x: Int) -> Int: return x + 1
def text(x: Int) -> String: return String(x)
def length(x: String) -> Int: return x.byte_length()
def suffix(x: String) -> String: return x + "!"
def raising_scalar(x: Int) raises String -> Int:
    if x == 2: raise String("raised")
    return x + 1
def raising_text(x: Int) raises String -> String: return String(x)
def raising_length(x: String) raises String -> Int: return x.byte_length()
def raising_suffix(x: String) raises String -> String: return x + "!"
def never_scalar(x: Int) raises Never -> Int: return x + 1
def never_text(x: Int) raises Never -> String: return String(x)
def never_length(x: String) raises Never -> Int: return x.byte_length()
def never_suffix(x: String) raises Never -> String: return x + "!"
def nothing(x: Int): pass
def nothing_never(x: Int) raises Never: pass
def nothing_raising(x: Int) raises String: raise String("void")

def forward[P: TrivialRegisterPassable, R: TrivialRegisterPassable](function: def(P) thin -> R, value: P) -> Tuple[P,R]:
    return pipeline[IdentityFamily](value).pair_with(function).get()

def main() raises:
    var a: def(Int) thin -> Int = scalar
    var b: def(Int) thin -> String = text
    var c: def(String) thin -> Int = length
    var d: def(String) thin -> String = suffix
    assert_equal(pipeline(4).pair_with(a).get()[1], 5)
    assert_equal(forward(a, 9)[1], 10)
    assert_equal(pipeline(4).pair_with(b).get()[1], "4")
    assert_equal(pipeline(String("abc")).pair_with(c).get()[1], 3)
    assert_equal(pipeline(String("abc")).pair_with(d).get()[1], "abc!")
    var e: def(Int) raises Never thin -> Int = never_scalar
    var f: def(Int) raises Never thin -> String = never_text
    var g: def(String) raises Never thin -> Int = never_length
    var h: def(String) raises Never thin -> String = never_suffix
    assert_equal(pipeline(4).raising[String]().pair_with(e).get()[1], 5)
    assert_equal(pipeline(4).raising[String]().pair_with(f).get()[1], "4")
    assert_equal(pipeline(String("abc")).raising[String]().pair_with(g).get()[1], 3)
    assert_equal(pipeline(String("abc")).raising[String]().pair_with(h).get()[1], "abc!")
    var i: def(Int) raises String thin -> Int = raising_scalar
    var j: def(Int) raises String thin -> String = raising_text
    var k: def(String) raises String thin -> Int = raising_length
    var l: def(String) raises String thin -> String = raising_suffix
    var r1: Tuple[Int,Int]
    var r2: Tuple[Int,String]
    var r3: Tuple[String,Int]
    var r4: Tuple[String,String]
    try:
        r1 = pipeline(4).raising[String]().pair_with(i).get()
        r2 = pipeline(4).raising[String]().pair_with(j).get()
        r3 = pipeline(String("abc")).raising[String]().pair_with(k).get()
        r4 = pipeline(String("abc")).raising[String]().pair_with(l).get()
    except _: raise Error("unexpected")
    assert_equal(r1[1], 5)
    assert_equal(r2[1], "4")
    assert_equal(r3[1], 3)
    assert_equal(r4[1], "abc!")
    var thrown = String()
    try: _ = pipeline(2).raising[String]().pair_with(i).get()
    except error: thrown = error^
    assert_equal(thrown, "raised")
    var p: def(Int) thin = nothing
    var q: def(Int) raises Never thin = nothing_never
    var r: def(Int) raises String thin = nothing_raising
    assert_equal(pipeline(7).tap(p).tap(q).get(), 7)
    var message = String()
    try: _ = pipeline(7).raising[String]().tap(r).get()
    except error: message = error^
    assert_equal(message, "void")
