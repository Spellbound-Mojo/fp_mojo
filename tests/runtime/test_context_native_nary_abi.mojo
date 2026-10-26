"""Stored native pointers preserve every arity and mixed operand/result conventions."""
from fp.functions import pipeline
from std.testing import assert_equal

def mixed_0_Int(var a0: String, var a1: String, var a2: String) -> Int:
    return a0.byte_length() + a1.byte_length() + a2.byte_length()

def mixed_0_String(var a0: String, var a1: String, var a2: String) -> String:
    return String(a0.byte_length() + a1.byte_length() + a2.byte_length())

def mixed_1_Int(var a0: String, var a1: String, var a2: Int) -> Int:
    return a0.byte_length() + a1.byte_length() + a2

def mixed_1_String(var a0: String, var a1: String, var a2: Int) -> String:
    return String(a0.byte_length() + a1.byte_length() + a2)

def mixed_2_Int(var a0: String, var a1: Int, var a2: String) -> Int:
    return a0.byte_length() + a1 + a2.byte_length()

def mixed_2_String(var a0: String, var a1: Int, var a2: String) -> String:
    return String(a0.byte_length() + a1 + a2.byte_length())

def mixed_3_Int(var a0: String, var a1: Int, var a2: Int) -> Int:
    return a0.byte_length() + a1 + a2

def mixed_3_String(var a0: String, var a1: Int, var a2: Int) -> String:
    return String(a0.byte_length() + a1 + a2)

def mixed_4_Int(var a0: Int, var a1: String, var a2: String) -> Int:
    return a0 + a1.byte_length() + a2.byte_length()

def mixed_4_String(var a0: Int, var a1: String, var a2: String) -> String:
    return String(a0 + a1.byte_length() + a2.byte_length())

def mixed_5_Int(var a0: Int, var a1: String, var a2: Int) -> Int:
    return a0 + a1.byte_length() + a2

def mixed_5_String(var a0: Int, var a1: String, var a2: Int) -> String:
    return String(a0 + a1.byte_length() + a2)

def mixed_6_Int(var a0: Int, var a1: Int, var a2: String) -> Int:
    return a0 + a1 + a2.byte_length()

def mixed_6_String(var a0: Int, var a1: Int, var a2: String) -> String:
    return String(a0 + a1 + a2.byte_length())

def mixed_7_Int(var a0: Int, var a1: Int, var a2: Int) -> Int:
    return a0 + a1 + a2

def mixed_7_String(var a0: Int, var a1: Int, var a2: Int) -> String:
    return String(a0 + a1 + a2)

def arity_1(var a0: Int) -> Int:
    return a0

def arity_2(var a0: Int, var a1: Optional[Int]) -> Int:
    return a0 + a1.value()

def arity_3(var a0: Int, var a1: String, var a2: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2.value()

def arity_4(var a0: Int, var a1: String, var a2: Int, var a3: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2 + a3.value()

def arity_5(var a0: Int, var a1: String, var a2: Int, var a3: String, var a4: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2 + a3.byte_length() + a4.value()

def arity_6(var a0: Int, var a1: String, var a2: Int, var a3: String, var a4: Int, var a5: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2 + a3.byte_length() + a4 + a5.value()

def arity_7(var a0: Int, var a1: String, var a2: Int, var a3: String, var a4: Int, var a5: String, var a6: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2 + a3.byte_length() + a4 + a5.byte_length() + a6.value()

def arity_8(var a0: Int, var a1: String, var a2: Int, var a3: String, var a4: Int, var a5: String, var a6: Int, var a7: Optional[Int]) -> Int:
    return a0 + a1.byte_length() + a2 + a3.byte_length() + a4 + a5.byte_length() + a6 + a7.value()

def main() raises:
    var mixed_0_Int_pointer: def(var String, var String, var String) thin -> Int = mixed_0_Int
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(String("ab")), Optional(String("ab"))), mixed_0_Int_pointer).get().value(), 6)
    var mixed_0_String_pointer: def(var String, var String, var String) thin -> String = mixed_0_String
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(String("ab")), Optional(String("ab"))), mixed_0_String_pointer).get().value(), "6")
    var mixed_1_Int_pointer: def(var String, var String, var Int) thin -> Int = mixed_1_Int
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(String("ab")), Optional(2)), mixed_1_Int_pointer).get().value(), 6)
    var mixed_1_String_pointer: def(var String, var String, var Int) thin -> String = mixed_1_String
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(String("ab")), Optional(2)), mixed_1_String_pointer).get().value(), "6")
    var mixed_2_Int_pointer: def(var String, var Int, var String) thin -> Int = mixed_2_Int
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(2), Optional(String("ab"))), mixed_2_Int_pointer).get().value(), 6)
    var mixed_2_String_pointer: def(var String, var Int, var String) thin -> String = mixed_2_String
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(2), Optional(String("ab"))), mixed_2_String_pointer).get().value(), "6")
    var mixed_3_Int_pointer: def(var String, var Int, var Int) thin -> Int = mixed_3_Int
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(2), Optional(2)), mixed_3_Int_pointer).get().value(), 6)
    var mixed_3_String_pointer: def(var String, var Int, var Int) thin -> String = mixed_3_String
    assert_equal(pipeline(Optional(String("ab"))).map_n((Optional(2), Optional(2)), mixed_3_String_pointer).get().value(), "6")
    var mixed_4_Int_pointer: def(var Int, var String, var String) thin -> Int = mixed_4_Int
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(String("ab"))), mixed_4_Int_pointer).get().value(), 6)
    var mixed_4_String_pointer: def(var Int, var String, var String) thin -> String = mixed_4_String
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(String("ab"))), mixed_4_String_pointer).get().value(), "6")
    var mixed_5_Int_pointer: def(var Int, var String, var Int) thin -> Int = mixed_5_Int
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2)), mixed_5_Int_pointer).get().value(), 6)
    var mixed_5_String_pointer: def(var Int, var String, var Int) thin -> String = mixed_5_String
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2)), mixed_5_String_pointer).get().value(), "6")
    var mixed_6_Int_pointer: def(var Int, var Int, var String) thin -> Int = mixed_6_Int
    assert_equal(pipeline(Optional(2)).map_n((Optional(2), Optional(String("ab"))), mixed_6_Int_pointer).get().value(), 6)
    var mixed_6_String_pointer: def(var Int, var Int, var String) thin -> String = mixed_6_String
    assert_equal(pipeline(Optional(2)).map_n((Optional(2), Optional(String("ab"))), mixed_6_String_pointer).get().value(), "6")
    var mixed_7_Int_pointer: def(var Int, var Int, var Int) thin -> Int = mixed_7_Int
    assert_equal(pipeline(Optional(2)).map_n((Optional(2), Optional(2)), mixed_7_Int_pointer).get().value(), 6)
    var mixed_7_String_pointer: def(var Int, var Int, var Int) thin -> String = mixed_7_String
    assert_equal(pipeline(Optional(2)).map_n((Optional(2), Optional(2)), mixed_7_String_pointer).get().value(), "6")
    var arity_1_pointer: def(var Int) thin -> Int = arity_1
    assert_equal(pipeline(Optional(2)).map_n((), arity_1_pointer).get().value(), 2)
    var arity_2_pointer: def(var Int, var Optional[Int]) thin -> Int = arity_2
    assert_equal(pipeline(Optional(2)).map_n((Optional(Optional(2)),), arity_2_pointer).get().value(), 4)
    var arity_3_pointer: def(var Int, var String, var Optional[Int]) thin -> Int = arity_3
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(Optional(2))), arity_3_pointer).get().value(), 6)
    var arity_4_pointer: def(var Int, var String, var Int, var Optional[Int]) thin -> Int = arity_4
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2), Optional(Optional(2))), arity_4_pointer).get().value(), 8)
    var arity_5_pointer: def(var Int, var String, var Int, var String, var Optional[Int]) thin -> Int = arity_5
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(Optional(2))), arity_5_pointer).get().value(), 10)
    var arity_6_pointer: def(var Int, var String, var Int, var String, var Int, var Optional[Int]) thin -> Int = arity_6
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(2), Optional(Optional(2))), arity_6_pointer).get().value(), 12)
    var arity_7_pointer: def(var Int, var String, var Int, var String, var Int, var String, var Optional[Int]) thin -> Int = arity_7
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(Optional(2))), arity_7_pointer).get().value(), 14)
    var arity_8_pointer: def(var Int, var String, var Int, var String, var Int, var String, var Int, var Optional[Int]) thin -> Int = arity_8
    assert_equal(pipeline(Optional(2)).map_n((Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(2), Optional(String("ab")), Optional(2), Optional(Optional(2))), arity_8_pointer).get().value(), 16)
