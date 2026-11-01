# error: invalid call to 'checked_attempt_tap': violated constraint
# error: constraint declared here evaluated to False
from context_outcome_receiver_support import checked_attempt_tap, MissingBorrow, MissingUnary, Positive, Label, Show, Next
from fp.algebra import ResultFamily
from fp.data import Result

def main():
    _ = checked_attempt_tap[ResultFamily[String]](ResultFamily[String].pure(3),MissingBorrow[Result[Int,String],Result[NoneType,String]]())
