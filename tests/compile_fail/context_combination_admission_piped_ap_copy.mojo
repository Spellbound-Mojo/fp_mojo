# error: invalid call to 'ap': violated constraint
from fp.algebra import ListFamily
from fp.functions import pipeline
from context_combination_admission_support import CapturedUnary,MoveState

def main() raises:
    _=pipeline(ListFamily.pure(CapturedUnary(MoveState(1)))).ap(List[Int]([2])).get()
