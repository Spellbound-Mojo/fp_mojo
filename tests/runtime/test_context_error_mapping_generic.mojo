"""Public error-mapping components support abstract and conditional forwarding."""
from fp.algebra import Functor, ErrorMapping, ResultFamily, ValidationFamily, StringMonoid, MapBothContract, MapErrContract
from fp.callables import UnaryContract, Unary
from fp.functions import Pipeline, pipeline
from fp.functions.composition import Identity
from fp.data import Result, Ok, Err
from std.builtin.rebind import downcast
from std.testing import assert_equal
from context_error_mapping_support import MappingOnly
from context_error_mapping_support import Show, Size

def components[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].SourceCompatible and MapBothContract[I,V,F,G,Target].InputCompatible and MapBothContract[I,V,F,G,Target].TargetCompatible and MapBothContract[I,V,F,G,Target].OutputCompatible and MapBothContract[I,V,F,G,Target].OperationCompatible:
    return pipeline[I](source^).map_both[Target=Target](f^,g^)

def combined[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].Compatible:
    return components[I,V,F,G,Target](source^,f^,g^)

def expanded[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].SourceCompatible and MapBothContract[I,V,F,G,Target].InputCompatible and MapBothContract[I,V,F,G,Target].TargetCompatible and MapBothContract[I,V,F,G,Target].OutputCompatible and MapBothContract[I,V,F,G,Target].OperationCompatible:
    return combined[I,V,F,G,Target](source^,f^,g^)

def witnessed[I: Functor, V: Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var source: V, var g: G) raises MapErrContract[downcast[I,ErrorMapping],V,G].Error -> Pipeline[MapErrContract[downcast[I,ErrorMapping],V,G].Family,MapErrContract[downcast[I,ErrorMapping],V,G].Out] where conforms_to(I,ErrorMapping) and MapErrContract[downcast[I,ErrorMapping],V,G].Compatible:
    return pipeline[I](source^).map_err(g^)

def witnessed_both[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping](var source: V, var f: F, var g: G) raises MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Error -> Pipeline[MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Family,MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Out] where conforms_to(I,ErrorMapping) and MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Compatible:
    return pipeline[I](source^).map_both[Target=Target](f^,g^)

@fieldwise_init
struct Replace[A: Movable & Deinitable, R: Copyable & Deinitable](Unary):
    var replacement: Self.R
    comptime Arg = Self.A
    comptime Out = Self.R
    def call(self,var value:Self.A)->Self.R:return self.replacement.copy()

def origins(left:List[Int],right:List[Int]) raises:
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    comptime I=ResultFamily[L]
    var value=Result[L,L](Err(Span(left)))
    var selected=witnessed_both[I,Target=ResultFamily[R]](value^,Identity[L](),Replace[L,R](Span(right)))
    comptime assert type_of(selected).I==ResultFamily[R]
    assert_equal(selected^.get()._err().value.unsafe_ptr()==Span(right).unsafe_ptr(),True)

@fieldwise_init
struct Prefix(Unary):
    comptime Arg = String
    comptime Out = String
    def call(self,var error:String)->String:return "mapped:"+error

def main() raises:
    origins(List[Int]([1]),List[Int]([2]))
    comptime R = ResultFamily[String]
    var first = combined[R](R.pure(3),Show(),Size())
    comptime assert type_of(first).I == ResultFamily[Int]
    assert_equal(first^.get()._ok().value,"3")
    assert_equal(expanded[R](R.fail[Int](String("four")),Show(),Size()).get()._err().value,4)
    assert_equal(witnessed[R](R.fail[Int](String("five")),Size()).get()._err().value,4)
    comptime V = ValidationFamily[StringMonoid]
    var retained = expanded[V](V.fail[Int](String("old")),Show(),Prefix())
    comptime assert type_of(retained).I == V
    assert_equal(retained^.get()._err().value,"mapped:old")
    var custom = witnessed[MappingOnly[String]](R.fail[Int](String("custom")),Size())
    comptime assert type_of(custom).I == MappingOnly[Int]
    assert_equal(custom^.get()._err().value,6)
