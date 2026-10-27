# error: no matching method in call to 'map_err'
from fp.algebra import StringMonoid, ValidationFamily
from fp.effects import ReaderT, StateT, WriterT
from fp.functions import pipeline
from context_error_mapping_nonmonad_support import ToValidation
def tag(var error: String) -> String: return "mapped:" + error
def main():
    # The base's default is valid; retaining a transformer requires a Monad.
    var direct = pipeline[ToValidation](ToValidation.pure(1)).map_err(tag)
    comptime assert type_of(direct).I == ValidationFamily[StringMonoid]
    _ = direct^.get()
    comptime I = WriterT[ToValidation,StringMonoid]
    _ = pipeline[I](I.pure(1)).map_err(tag)
