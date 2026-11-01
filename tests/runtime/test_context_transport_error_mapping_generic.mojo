"""Public contracts retain target families through abstract and conditional clients."""
from fp.algebra import Functor, ErrorMapping, ResultFamily, StringMonoid
from fp.algebra.contracts import MapBothContract, MapErrContract
from fp.callables import UnaryContract
from fp.effects import ReaderT, StateT, WriterT, run, run_writer
from fp.functions import Pipeline, pipeline
from std.builtin.rebind import downcast
from std.testing import assert_equal
from context_error_mapping_support import Show, Size

def components[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].SourceCompatible and MapBothContract[I,V,F,G,Target].InputCompatible and MapBothContract[I,V,F,G,Target].TargetCompatible and MapBothContract[I,V,F,G,Target].OutputCompatible and MapBothContract[I,V,F,G,Target].OperationCompatible:
    return pipeline[I](source^).map_both[Target=Target](f^,g^)

def combined[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].Compatible:
    return components[I,V,F,G,Target](source^,f^,g^)

def expanded[I: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](var source: V, var f: F, var g: G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].SourceCompatible and MapBothContract[I,V,F,G,Target].InputCompatible and MapBothContract[I,V,F,G,Target].TargetCompatible and MapBothContract[I,V,F,G,Target].OutputCompatible and MapBothContract[I,V,F,G,Target].OperationCompatible:
    return combined[I,V,F,G,Target](source^,f^,g^)

def witnessed[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, Target: ErrorMapping](var source: V, var f: F, var g: G) raises MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Error -> Pipeline[MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Family,MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Out] where conforms_to(I,ErrorMapping) and MapBothContract[downcast[I,ErrorMapping],V,F,G,Target].Compatible:
    return pipeline[I](source^).map_both[Target=Target](f^,g^)

def error_only[I: ErrorMapping, V: Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var source: V, var g: G) raises MapErrContract[I,V,G].Error -> Pipeline[MapErrContract[I,V,G].Family,MapErrContract[I,V,G].Out] where MapErrContract[I,V,G].Compatible:
    return pipeline[I](source^).map_err(g^)

def main() raises:
    comptime R = ReaderT[ResultFamily[String],Int]
    comptime R2 = ReaderT[ResultFamily[Int],Int]
    comptime S = StateT[ResultFamily[String],Int]
    comptime S2 = StateT[ResultFamily[Int],Int]
    comptime W = WriterT[ResultFamily[String],StringMonoid]
    comptime W2 = WriterT[ResultFamily[Int],StringMonoid]
    var reader = expanded[R](R.pure(12),Show(),Size())
    comptime assert type_of(reader).I == R2
    def length(var value: String) -> Int: return value.byte_length()
    assert_equal(run[R2](reader^.map(length).get(),0)._ok().value,2)
    var state = combined[S](S.pure(13),Show(),Size())
    comptime assert type_of(state).I == S2
    var result = run[S2](state^.get(),9)
    assert_equal(result._ok().value[0],"13")
    assert_equal(result._ok().value[1],9)
    var logged = witnessed[W,Target=W2](W.pure(14),Show(),Size())
    comptime assert type_of(logged).I == W2
    assert_equal(run_writer[W2](logged^.get())._ok().value[1],"14")
    assert_equal(run[R2](witnessed[R,Target=R2](R.fail[Int](String("four")),Show(),Size()).get(),0)._err().value,4)
    assert_equal(run[S2](error_only[S](S.fail[Int](String("five")),Size()).get(),8)._err().value,4)
    assert_equal(run_writer[W2](error_only[W](W.fail[Int](String("six")),Size()).get())._err().value,3)
