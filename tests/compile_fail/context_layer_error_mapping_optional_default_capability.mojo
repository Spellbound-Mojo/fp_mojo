# error: no matching method in call to 'map_err'
from context_error_mapping_nonmonad_support import ToValidation
from fp.algebra import StringMonoid, ValidationFamily
from fp.effects import OptionalT
from fp.functions import pipeline

def tag(var error:String)->String:return "mapped:"+error
def main():
    var direct=pipeline[ToValidation](ToValidation.pure(1)).map_err(tag)
    comptime assert type_of(direct).I==ValidationFamily[StringMonoid]
    _=direct^.get()
    comptime I=OptionalT[ToValidation]
    _=pipeline[I](I.pure(1)).map_err(tag)
