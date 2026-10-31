from fp.algebra import ErrorMapping
from fp.algebra.contracts import MapBothContract, MapErrContract
from fp.callables import UnaryContract
from fp.functions import Pipeline, pipeline

def legacy_both[I:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[F.Out,G.Out]](var source:V,var on_ok:F,var on_err:G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].Compatible:
    return pipeline[I](source^).map_both[Target=Target](on_ok^,on_err^)

def checked_both[I:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[F.Out,G.Out]](var source:V,var on_ok:F,var on_err:G) raises MapBothContract[I,V,F,G,Target].Error -> Pipeline[MapBothContract[I,V,F,G,Target].Family,MapBothContract[I,V,F,G,Target].Out] where MapBothContract[I,V,F,G,Target].InvocationCompatible:
    return legacy_both[I,V,F,G,Target](source^,on_ok^,on_err^)

def legacy_error[I:ErrorMapping,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[I.Element[V],G.Out]](var source:V,var on_err:G) raises MapErrContract[I,V,G,Target].Error -> Pipeline[MapErrContract[I,V,G,Target].Family,MapErrContract[I,V,G,Target].Out] where MapErrContract[I,V,G,Target].Compatible:
    return pipeline[I](source^).map_err[Target=Target](on_err^)

def checked_error[I:ErrorMapping,V:Movable & Deinitable,G:UnaryContract & Movable & Deinitable,Target:ErrorMapping=I.DefaultErrorTarget[I.Element[V],G.Out]](var source:V,var on_err:G) raises MapErrContract[I,V,G,Target].Error -> Pipeline[MapErrContract[I,V,G,Target].Family,MapErrContract[I,V,G,Target].Out] where MapErrContract[I,V,G,Target].InvocationCompatible:
    return legacy_error[I,V,G,Target](source^,on_err^)
