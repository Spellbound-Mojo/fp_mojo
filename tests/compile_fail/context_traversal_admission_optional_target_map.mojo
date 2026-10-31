# error: no matching method in call to 'traverse'
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily, traverse
from fp.effects import OptionalT,ResultT
from fp.functions import pipeline,piped
from fp.iteration import traverse as collect,iterated
from fp.data import NonEmptyList
from context_traversal_admission_support import MoveState,Next,OnceNext,OnceOwned,RepeatedOwned,AdmissionBase

def main() raises:
    comptime I=AdmissionBase[ListFamily,False]
    _=pipeline(Optional(1)).traverse[I](OnceOwned()).get()
