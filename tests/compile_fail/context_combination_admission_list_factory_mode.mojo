# error: invalid call to 'map2_lazy'
from fp.algebra import ListFamily, ResultFamily, map2_lazy
from fp.effects import OptionalT, ResultT
from fp.functions import pipeline, piped
from fp.callables._transforms import _ValueThunk
from context_combination_admission_support import Add,OnceAdd,CapturedAdd,MoveLeft,MoveRight,MoveState,Missing,ErrorAdd,OtherError,AdmissionBase

def main() raises:
    _=map2_lazy[ListFamily](Add(),List[Int]([1]),Missing())
