# error: invalid call to 'checked_ensure': violated constraint
# error: constraint declared here evaluated to False
from context_outcome_receiver_support import checked_ensure, MissingBorrow, MissingUnary, Positive, Label, Show, Next
from fp.algebra import ResultFamily
from fp.data import Result

def main():
    _ = checked_ensure[ResultFamily[String]](ResultFamily[String].pure(3),Positive(),MissingBorrow[Int,String]())
