"""Generic effect searches preserve exact callback errors and embedded origins."""
from fp.iteration import iterated, find_effect, find_map_effect, fold_map_effect
from fp.functions import piped
from fp.algebra import OptionalFamily, StringMonoid, ListMonoid
from std.testing import assert_equal


def i6g_find[P:Movable & Deinitable,R:Movable & Deinitable,E:Movable & Deinitable,//,F:def(P) raises E -> R](ref function:F,var values:List[P]) raises E ->Optional[Optional[P]] where R==Optional[Bool] and OptionalFamily.Element[R]==Bool and OptionalFamily.CarrierCompatible[R]:
    return iterated(values^).find_effect[G=OptionalFamily,P=P,R=R,E=E,X=E](function)


def i6g_map[A:Movable & Deinitable,B:Movable & Deinitable,E:Movable & Deinitable,//,F:def(var A) raises E -> Optional[Optional[B]]](ref function:F,var values:List[A]) raises E ->Optional[Optional[B]]:
    return find_map_effect[G=OptionalFamily,A=A,E=E,X=E](function,values^)


def i6g_fold[A:Movable & Deinitable,R:Movable & Deinitable,E:Movable & Deinitable,//,F:def(var A) raises E -> R](ref function:F,var values:List[A]) raises E ->Optional[String] where R==Optional[String] and OptionalFamily.Element[R]==String and OptionalFamily.CarrierCompatible[R]:
    return piped(values^).fold_map_effect[G=OptionalFamily,M=StringMonoid,A=A,R=R,E=E,X=E](function).get()


@fieldwise_init
struct I6GenericFailure(Movable):
    var code:Int

def i6g_bool(value:Int) raises I6GenericFailure -> Optional[Bool]:
    if value<0:raise I6GenericFailure(value)
    return Optional(value==2)
def i6g_optional(var value:Int) raises I6GenericFailure -> Optional[Optional[String]]:
    if value<0:raise I6GenericFailure(value)
    return Optional(Optional(String(value)) if value==2 else Optional[String]())
def i6g_string(var value:Int) raises I6GenericFailure -> Optional[String]:
    if value<0:raise I6GenericFailure(value)
    return Optional(String(value))


def origins(anchor:List[Int]) raises:
    comptime View=Span[Int,origin_of(anchor)]
    def select(value:View)->Optional[Bool]:return Optional(value[0]==11)
    def project(var value:View)->Optional[Optional[View]]:return Optional(Optional(value))
    def collect(var value:View)->Optional[List[View]]:
        var xs=List[View]()
        xs.append(value)
        return Optional(xs^)
    var values=List[View]()
    values.append(Span(anchor));values.append(Span(anchor))
    var found=find_effect[OptionalFamily](select,values.copy())
    assert_equal(found.value().value()[1],12)
    var mapped=find_map_effect[OptionalFamily](project,values.copy())
    assert_equal(mapped.value().value()[0],11)
    var folded=fold_map_effect[OptionalFamily,ListMonoid[View]](collect,values^)
    assert_equal(folded.value()[1][1],12)


def main() raises:
    var values:List[Int]=[1,2,3]
    var found:Optional[Optional[Int]]
    var mapped:Optional[Optional[String]]
    var folded:Optional[String]
    try:
        found=i6g_find(i6g_bool,values.copy())
        mapped=i6g_map[B=String](i6g_optional,values.copy())
        folded=i6g_fold(i6g_string,values.copy())
    except:raise Error("unexpected native error")
    assert_equal(found.value().value(),2)
    assert_equal(mapped.value().value(),"2")
    assert_equal(folded.value(),"123")
    var bad:List[Int]=[1,-2,3]
    var code=0
    try:_=i6g_find(i6g_bool,bad.copy())
    except error:
        comptime assert type_of(error)==I6GenericFailure
        code=error.code
    assert_equal(code,-2)
    code=0
    try:_=i6g_map[B=String](i6g_optional,bad.copy())
    except error:code=error.code
    assert_equal(code,-2)
    code=0
    try:_=i6g_fold(i6g_string,bad^)
    except error:code=error.code
    assert_equal(code,-2)
    origins([11,12])
