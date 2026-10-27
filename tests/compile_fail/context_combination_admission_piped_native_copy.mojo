# error: no matching method in call to 'map2'
from fp.algebra import ListFamily, ResultFamily, map2_lazy
from fp.effects import OptionalT, ResultT
from fp.functions import pipeline, piped
from fp.callables._transforms import _ValueThunk
from context_combination_admission_support import Add,OnceAdd,CapturedAdd,MoveLeft,MoveRight,MoveState,Missing,ErrorAdd,OtherError,AdmissionBase

def main() raises:
    def add(var first:MoveState,var second:Int)->Int:return first.value+second
    _=piped(ListFamily.pure(MoveState(1))).map2(List[Int]([2]),add).get()
