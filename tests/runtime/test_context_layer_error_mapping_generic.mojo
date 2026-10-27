"""Layer mappings forward public combined, component and conditional contracts."""
from fp.algebra import Monad, Functor, ErrorMapping, ListFamily, ResultFamily, MapBothContract, MapErrContract
from fp.callables import UnaryContract
from fp.functions import pipeline, Pipeline
from fp.effects import ResultT, OptionalT, Reader, run
from fp.data import Result, Ok, Err
from std.builtin.rebind import downcast
from std.testing import assert_equal
from context_error_mapping_support import Show, Size
from context_layer_error_mapping_support import MappingMonad
from test_context_error_mapping_generic import combined, expanded, witnessed

def err_components[I:ErrorMapping,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[I.Element[V],G.Out]](var source:V,var g:G) raises MapErrContract[I,V,G,Target].Error ->Pipeline[MapErrContract[I,V,G,Target].Family,MapErrContract[I,V,G,Target].Out] where MapErrContract[I,V,G,Target].SourceCompatible and MapErrContract[I,V,G,Target].InputCompatible and MapErrContract[I,V,G,Target].TargetCompatible and MapErrContract[I,V,G,Target].OutputCompatible and MapErrContract[I,V,G,Target].OperationCompatible:
    return pipeline[I](source^).map_err[Target=Target](g^)

def err_combined[I:ErrorMapping,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[I.Element[V],G.Out]](var source:V,var g:G) raises MapErrContract[I,V,G,Target].Error ->Pipeline[MapErrContract[I,V,G,Target].Family,MapErrContract[I,V,G,Target].Out] where MapErrContract[I,V,G,Target].Compatible:
    return err_components[I,V,G,Target](source^,g^)

def err_expanded[I:ErrorMapping,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[I.Element[V],G.Out]](var source:V,var g:G) raises MapErrContract[I,V,G,Target].Error ->Pipeline[MapErrContract[I,V,G,Target].Family,MapErrContract[I,V,G,Target].Out] where MapErrContract[I,V,G,Target].SourceCompatible and MapErrContract[I,V,G,Target].InputCompatible and MapErrContract[I,V,G,Target].TargetCompatible and MapErrContract[I,V,G,Target].OutputCompatible and MapErrContract[I,V,G,Target].OperationCompatible:
    return err_combined[I,V,G,Target](source^,g^)

def conditional_optional[M:Monad,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable](var source:V,var g:G) raises MapErrContract[downcast[OptionalT[M],ErrorMapping],V,G].Error ->MapErrContract[downcast[OptionalT[M],ErrorMapping],V,G].Out where conforms_to(OptionalT[M],ErrorMapping) and MapErrContract[downcast[OptionalT[M],ErrorMapping],V,G].Compatible:
    return witnessed[OptionalT[M]](source^,g^).get()

def conditional_both[I:Functor,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:Functor](var source:V,var f:F,var g:G) raises MapBothContract[downcast[I,ErrorMapping],V,F,G,downcast[Target,ErrorMapping]].Error ->Pipeline[MapBothContract[downcast[I,ErrorMapping],V,F,G,downcast[Target,ErrorMapping]].Family,MapBothContract[downcast[I,ErrorMapping],V,F,G,downcast[Target,ErrorMapping]].Out] where conforms_to(I,ErrorMapping) and conforms_to(Target,ErrorMapping) and MapBothContract[downcast[I,ErrorMapping],V,F,G,downcast[Target,ErrorMapping]].Compatible:
    return pipeline[I](source^).map_both[Target=Target](f^,g^)

def conditional_err[I:Functor,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:Functor](var source:V,var g:G) raises MapErrContract[downcast[I,ErrorMapping],V,G,downcast[Target,ErrorMapping]].Error ->Pipeline[MapErrContract[downcast[I,ErrorMapping],V,G,downcast[Target,ErrorMapping]].Family,MapErrContract[downcast[I,ErrorMapping],V,G,downcast[Target,ErrorMapping]].Out] where conforms_to(I,ErrorMapping) and conforms_to(Target,ErrorMapping) and MapErrContract[downcast[I,ErrorMapping],V,G,downcast[Target,ErrorMapping]].Compatible:
    return pipeline[I](source^).map_err[Target=Target](g^)

def native_list[A:Movable & Deinitable,E:Movable & Deinitable,B:Movable & Deinitable,G:Movable & Deinitable,X:Movable & Deinitable,//,F:def(var A) raises X ->B,H:def(var E) raises X ->G](var source:List[Result[A,E]],f:F,h:H) raises X ->List[Result[B,G]]:
    return pipeline[ResultT[ListFamily,E]](source^).raising[X]().map_both(f,h).get()

def native_optional[A:Movable & Deinitable,E:Movable & Deinitable,B:Movable & Deinitable,G:Movable & Deinitable,X:Movable & Deinitable,//,F:def(var A) raises X ->B,H:def(var E) raises X ->G](var source:Result[Optional[A],E],f:F,h:H) raises X ->Result[Optional[B],G]:
    return pipeline[OptionalT[ResultFamily[E]]](source^).raising[X]().map_both(f,h).get()

def main() raises:
    def show(var value:Int) raises Never ->String:return String(value)
    def size(var error:String) raises Never ->Int:return error.byte_length()
    assert_equal(native_list(List[Result[Int,String]]([Result[Int,String](Ok(3))]),show,size)[0]._ok().value,"3")
    assert_equal(native_optional(Result[Optional[Int],String](Ok(Optional(4))),show,size)._ok().value.value(),"4")
    def throwing(var value:Int) raises Int ->String:raise value
    def same_error(var error:String) raises Int ->Int:return error.byte_length()
    var code=0
    try:_=native_list(List[Result[Int,String]]([Result[Int,String](Ok(9))]),throwing,same_error)
    except error:code=error
    assert_equal(code,9)
    try:_=native_optional(Result[Optional[Int],String](Ok(Optional(10))),throwing,same_error)
    except error:code=error
    assert_equal(code,10)
    comptime L = ResultT[ListFamily,String]
    comptime Changed = ResultT[ListFamily,Int]
    var mapped = combined[L](L.pure(4),Show(),Size())
    comptime assert type_of(mapped).I == Changed
    assert_equal(mapped^.get()[0]._ok().value,"4")
    assert_equal(expanded[L](L.fail[Int](String("five")),Show(),Size()).get()[0]._err().value,4)
    assert_equal(err_combined[L](L.fail[Int](String("six")),Size()).get()[0]._err().value,3)
    assert_equal(err_expanded[L](L.pure(7),Size()).get()[0]._ok().value,7)
    comptime O = OptionalT[ResultFamily[String]]
    var changed = conditional_both[O,Target=OptionalT[ResultFamily[Int]]](O.pure(8),Show(),Size())
    assert_equal(changed^.get()._ok().value.value(),"8")
    assert_equal(conditional_optional[ResultFamily[String]](O.fail[Int](String("nine")),Size())._err().value,4)
    assert_equal(conditional_err[O,Target=OptionalT[ResultFamily[Int]]](O.pure(10),Size()).get()._ok().value.value(),10)
    comptime Mapping = OptionalT[MappingMonad[String]]
    var only = conditional_optional[MappingMonad[String]](Result[Optional[Int],String](Err(String("only"))),Size())
    assert_equal(only._err().value,4)
    comptime R = Reader[Int]
    comptime Deferred = ResultT[R,String]
    assert_equal(run[R](combined[Deferred](Deferred.pure(11),Show(),Size()).get(),0)._ok().value,"11")
    assert_equal(run[R](witnessed[Deferred](Deferred.fail[Int](String("twelve")),Size()).get(),0)._err().value,6)
