# error: invalid call to 'ap': violated constraint
from fp.algebra import ListFamily
from fp.functions import piped
from context_combination_admission_support import CapturedUnary,MoveState

def main() raises:
    _=piped(ListFamily.pure(CapturedUnary(MoveState(1)))).ap(List[Int]([2])).get()
