"""Stored n-ary pointers keep exact native errors, no-value returns and validation order."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import StringMonoid
from std.testing import assert_equal

def add(var a: Int, var b: String, var c: Int) -> Int: return a + b.byte_length() + c
def never(var a: Int, var b: String, var c: Int) raises Never -> Int: return add(a, b^, c)
def failure(var a: Int, var b: String, var c: Int) raises Int -> Int: raise add(a, b^, c)
def nothing(var a: Int, var b: String, var c: Int): pass
def nothing_never(var a: Int, var b: String, var c: Int) raises Never: pass
def nothing_fails(var a: Int, var b: String, var c: Int) raises Int: raise a + c
def one(var a: Int): pass
def two(var a: Int, var b: String) raises Never: pass
def eight(var a:Int,var b:Int,var c:Int,var d:Int,var e:Int,var f:Int,var g:Int,var h:Int) raises Int:
    raise a+b+c+d+e+f+g+h

def forward[R: RegisterPassable & Deinitable](function: def(var Int, var String, var Int) raises Int thin -> R) raises Int -> Result[R, List[String]]:
    return pipeline(Result[Int, List[String]](Ok(1))).raising[Int]().par_map_n((Result[String, List[String]](Ok(String("b"))), Result[Int, List[String]](Ok(3))), function).get()

def main() raises:
    var pure: def(var Int, var String, var Int) thin -> Int = add
    assert_equal(pipeline(Result[Int, String](Ok(1))).par_map_n[StringMonoid]((Result[String, String](Ok(String("b"))), Result[Int, String](Ok(3))), pure).get()._ok().value, 5)
    var failed = pipeline(Result[Int, List[String]](Err(List[String](["a"])))).par_map_n((Result[String, List[String]](Err(List[String](["b"]))), Result[Int, List[String]](Ok(3))), pure).get()
    assert_equal(failed._err().value, List[String](["a", "b"]))
    var literal: def(var Int, var String, var Int) raises Never thin -> Int = never
    assert_equal(pipeline(Optional(1)).raising[Int]().map_n((Optional(String("b")), Optional(3)), literal).get().value(), 5)
    var raising: def(var Int, var String, var Int) raises Int thin -> Int = failure
    var code = 0
    try: _ = forward(raising)
    except error: code = error
    assert_equal(code, 5)
    # Mojo's inferred native no-value return has its own register ABI.
    var void: def(var Int, var String, var Int) thin = nothing
    var void_never: def(var Int, var String, var Int) raises Never thin = nothing_never
    var void_raising: def(var Int, var String, var Int) raises Int thin = nothing_fails
    _ = pipeline(Optional(1)).map_n((Optional(String("b")), Optional(3)), void).get()
    _ = pipeline(Optional(1)).raising[Int]().map_n((Optional(String("b")), Optional(3)), void_never).get()
    try: _ = forward(void_raising)
    except error: code = error
    assert_equal(code, 4)
    var unary: def(var Int) thin = one
    var binary: def(var Int, var String) raises Never thin = two
    var largest: def(var Int,var Int,var Int,var Int,var Int,var Int,var Int,var Int) raises Int thin = eight
    _ = pipeline(Optional(1)).map_n((), unary).get()
    _ = pipeline(Optional(1)).map_n((Optional(String("x")),), binary).get()
    try: _ = pipeline(Optional(1)).raising[Int]().map_n((Optional(2),Optional(3),Optional(4),Optional(5),Optional(6),Optional(7),Optional(8)), largest).get()
    except error: code = error
    assert_equal(code, 36)
