# error: no matching method in call to 'map2'
from fp.algebra import ListFamily, ResultFamily, map2_lazy
from fp.effects import OptionalT, ResultT
from fp.functions import pipeline
from fp.callables._transforms import _ValueThunk
from context_combination_admission_support import Add,OnceAdd,CapturedAdd,MoveLeft,MoveRight,MoveState,Missing,ErrorAdd,OtherError,AdmissionBase

def main() raises:
    _=pipeline(List[Int]([1])).map2(List[Int]([2]),OnceAdd()).get()
