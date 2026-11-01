# error: invalid call to 'sequence'
from fp.algebra import ListFamily, OptionalFamily, NonEmptyListFamily, traverse
from fp.effects import OptionalT,ResultT
from fp.functions import pipeline
from fp.iteration import traverse as collect,iterated
from fp.data import NonEmptyList
from context_traversal_admission_support import MoveState,Next,OnceNext,OnceOwned,RepeatedOwned,AdmissionBase

def main() raises:
    _=pipeline(ListFamily.pure(ListFamily.pure(MoveState(1)))).sequence[ListFamily]().get()
