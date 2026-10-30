from fp.iteration import map_accumulate, iterated
from std.testing import assert_equal
def step_Int_Int_0(var a: Int,var t: Int) -> Tuple[Int,Int]: return (a,t)
comptime Ptr_Int_Int_0 = def(var Int,var Int) thin -> Tuple[Int,Int]
def step_Int_Int_13(var a: Int,var t: Int) raises Never -> Tuple[Int,Int]: return (a,t)
comptime Ptr_Int_Int_13 = def(var Int,var Int) raises Never thin -> Tuple[Int,Int]
def step_Int_Int_11(var a: Int,var t: Int) raises Int -> Tuple[Int,Int]: return (a,t)
comptime Ptr_Int_Int_11 = def(var Int,var Int) raises Int thin -> Tuple[Int,Int]
def step_Int_String_0(var a: Int,var t: String) -> Tuple[Int,String]: return (a,t^)
comptime Ptr_Int_String_0 = def(var Int,var String) thin -> Tuple[Int,String]
def step_Int_String_13(var a: Int,var t: String) raises Never -> Tuple[Int,String]: return (a,t^)
comptime Ptr_Int_String_13 = def(var Int,var String) raises Never thin -> Tuple[Int,String]
def step_Int_String_11(var a: Int,var t: String) raises Int -> Tuple[Int,String]: return (a,t^)
comptime Ptr_Int_String_11 = def(var Int,var String) raises Int thin -> Tuple[Int,String]
def step_String_Int_0(var a: String,var t: Int) -> Tuple[String,Int]: return (a^,t)
comptime Ptr_String_Int_0 = def(var String,var Int) thin -> Tuple[String,Int]
def step_String_Int_13(var a: String,var t: Int) raises Never -> Tuple[String,Int]: return (a^,t)
comptime Ptr_String_Int_13 = def(var String,var Int) raises Never thin -> Tuple[String,Int]
def step_String_Int_11(var a: String,var t: Int) raises Int -> Tuple[String,Int]: return (a^,t)
comptime Ptr_String_Int_11 = def(var String,var Int) raises Int thin -> Tuple[String,Int]
def step_String_String_0(var a: String,var t: String) -> Tuple[String,String]: return (a^,t^)
comptime Ptr_String_String_0 = def(var String,var String) thin -> Tuple[String,String]
def step_String_String_13(var a: String,var t: String) raises Never -> Tuple[String,String]: return (a^,t^)
comptime Ptr_String_String_13 = def(var String,var String) raises Never thin -> Tuple[String,String]
def step_String_String_11(var a: String,var t: String) raises Int -> Tuple[String,String]: return (a^,t^)
comptime Ptr_String_String_11 = def(var String,var String) raises Int thin -> Tuple[String,String]
def main() raises:
    var p_Int_Int_0: Ptr_Int_Int_0 = step_Int_Int_0
    var r_Int_Int_0 = iterated([9]).map_accumulate[Y=Int](p_Int_Int_0,7)
    assert_equal(r_Int_Int_0[0],7)
    assert_equal(r_Int_Int_0[1][0],9)
    var d_Int_Int_0 = map_accumulate([9],7,step_Int_Int_0)
    assert_equal(d_Int_Int_0[0],7)
    assert_equal(d_Int_Int_0[1][0],9)
    var p_Int_Int_13: Ptr_Int_Int_13 = step_Int_Int_13
    var r_Int_Int_13 = iterated([9]).map_accumulate[Y=Int](p_Int_Int_13,7)
    assert_equal(r_Int_Int_13[0],7)
    assert_equal(r_Int_Int_13[1][0],9)
    var d_Int_Int_13 = map_accumulate([9],7,step_Int_Int_13)
    assert_equal(d_Int_Int_13[0],7)
    assert_equal(d_Int_Int_13[1][0],9)
    var p_Int_Int_11: Ptr_Int_Int_11 = step_Int_Int_11
    var r_Int_Int_11 = iterated([9]).map_accumulate[Y=Int,E=Int](p_Int_Int_11,7)
    assert_equal(r_Int_Int_11[0],7)
    assert_equal(r_Int_Int_11[1][0],9)
    var d_Int_Int_11 = map_accumulate([9],7,step_Int_Int_11)
    assert_equal(d_Int_Int_11[0],7)
    assert_equal(d_Int_Int_11[1][0],9)
    var p_Int_String_0: Ptr_Int_String_0 = step_Int_String_0
    var r_Int_String_0 = iterated([String("nine")]).map_accumulate[Y=String](p_Int_String_0,7)
    assert_equal(r_Int_String_0[0],7)
    assert_equal(r_Int_String_0[1][0],String("nine"))
    var d_Int_String_0 = map_accumulate([String("nine")],7,step_Int_String_0)
    assert_equal(d_Int_String_0[0],7)
    assert_equal(d_Int_String_0[1][0],String("nine"))
    var p_Int_String_13: Ptr_Int_String_13 = step_Int_String_13
    var r_Int_String_13 = iterated([String("nine")]).map_accumulate[Y=String](p_Int_String_13,7)
    assert_equal(r_Int_String_13[0],7)
    assert_equal(r_Int_String_13[1][0],String("nine"))
    var d_Int_String_13 = map_accumulate([String("nine")],7,step_Int_String_13)
    assert_equal(d_Int_String_13[0],7)
    assert_equal(d_Int_String_13[1][0],String("nine"))
    var p_Int_String_11: Ptr_Int_String_11 = step_Int_String_11
    var r_Int_String_11 = iterated([String("nine")]).map_accumulate[Y=String,E=Int](p_Int_String_11,7)
    assert_equal(r_Int_String_11[0],7)
    assert_equal(r_Int_String_11[1][0],String("nine"))
    var d_Int_String_11 = map_accumulate([String("nine")],7,step_Int_String_11)
    assert_equal(d_Int_String_11[0],7)
    assert_equal(d_Int_String_11[1][0],String("nine"))
    var p_String_Int_0: Ptr_String_Int_0 = step_String_Int_0
    var r_String_Int_0 = iterated([9]).map_accumulate[Y=Int](p_String_Int_0,String("seven"))
    assert_equal(r_String_Int_0[0],String("seven"))
    assert_equal(r_String_Int_0[1][0],9)
    var d_String_Int_0 = map_accumulate([9],String("seven"),step_String_Int_0)
    assert_equal(d_String_Int_0[0],String("seven"))
    assert_equal(d_String_Int_0[1][0],9)
    var p_String_Int_13: Ptr_String_Int_13 = step_String_Int_13
    var r_String_Int_13 = iterated([9]).map_accumulate[Y=Int](p_String_Int_13,String("seven"))
    assert_equal(r_String_Int_13[0],String("seven"))
    assert_equal(r_String_Int_13[1][0],9)
    var d_String_Int_13 = map_accumulate([9],String("seven"),step_String_Int_13)
    assert_equal(d_String_Int_13[0],String("seven"))
    assert_equal(d_String_Int_13[1][0],9)
    var p_String_Int_11: Ptr_String_Int_11 = step_String_Int_11
    var r_String_Int_11 = iterated([9]).map_accumulate[Y=Int,E=Int](p_String_Int_11,String("seven"))
    assert_equal(r_String_Int_11[0],String("seven"))
    assert_equal(r_String_Int_11[1][0],9)
    var d_String_Int_11 = map_accumulate([9],String("seven"),step_String_Int_11)
    assert_equal(d_String_Int_11[0],String("seven"))
    assert_equal(d_String_Int_11[1][0],9)
    var p_String_String_0: Ptr_String_String_0 = step_String_String_0
    var r_String_String_0 = iterated([String("nine")]).map_accumulate[Y=String](p_String_String_0,String("seven"))
    assert_equal(r_String_String_0[0],String("seven"))
    assert_equal(r_String_String_0[1][0],String("nine"))
    var d_String_String_0 = map_accumulate([String("nine")],String("seven"),step_String_String_0)
    assert_equal(d_String_String_0[0],String("seven"))
    assert_equal(d_String_String_0[1][0],String("nine"))
    var p_String_String_13: Ptr_String_String_13 = step_String_String_13
    var r_String_String_13 = iterated([String("nine")]).map_accumulate[Y=String](p_String_String_13,String("seven"))
    assert_equal(r_String_String_13[0],String("seven"))
    assert_equal(r_String_String_13[1][0],String("nine"))
    var d_String_String_13 = map_accumulate([String("nine")],String("seven"),step_String_String_13)
    assert_equal(d_String_String_13[0],String("seven"))
    assert_equal(d_String_String_13[1][0],String("nine"))
    var p_String_String_11: Ptr_String_String_11 = step_String_String_11
    var r_String_String_11 = iterated([String("nine")]).map_accumulate[Y=String,E=Int](p_String_String_11,String("seven"))
    assert_equal(r_String_String_11[0],String("seven"))
    assert_equal(r_String_String_11[1][0],String("nine"))
    var d_String_String_11 = map_accumulate([String("nine")],String("seven"),step_String_String_11)
    assert_equal(d_String_String_11[0],String("seven"))
    assert_equal(d_String_String_11[1][0],String("nine"))
