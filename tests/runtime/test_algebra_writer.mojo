from fp.algebra import pure, map, flat_map
from fp.algebra import map2
from fp.algebra import StringMonoid
from fp.effects import Writer, WriterT, writer, run_writer, tell, listen, censor, Reader, run, lift
from fp.callables import as_unary
from std.testing import assert_equal
from algebra_support import Add, increment as inc

comptime W = Writer[StringMonoid]

def next(var x:Int) -> type_of(writer[W,Int](Tuple(String(),Int()))):
    return writer[W,Int](Tuple(String("b"),x+2))

def tag(var s:String)->String:
    return s + "!"

def main() raises:
    var wrapped=writer[W,Int](Tuple(String("native"),7))
    var base=wrapped^.into_base()
    assert_equal(base[0],"native")
    assert_equal(base[1],7)
    var p = run_writer[W](pure[W](3))
    assert_equal(p[0],"")
    assert_equal(p[1],3)
    p=run_writer[W](map[W](as_unary(inc),writer[W,Int](Tuple(String("a"),1))))
    assert_equal(p[0],"a")
    assert_equal(p[1],2)
    p=run_writer[W](flat_map[W](as_unary(next),writer[W,Int](Tuple(String("a"),1))))
    assert_equal(p[0],"ab")
    assert_equal(p[1],3)
    var t=run_writer[W](tell[W]("hi"))
    assert_equal(t[0],"hi")
    var l=run_writer[W](listen[W](writer[W,Int](Tuple(String("a"),1))))
    assert_equal(l[0],"a")
    assert_equal(l[1][1],"a")
    p=run_writer[W](censor[W](as_unary(tag),writer[W,Int](Tuple(String("a"),1))))
    assert_equal(p[0],"a!")
    print("writer ok")
