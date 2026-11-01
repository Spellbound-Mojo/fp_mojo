# error: invalid call to 'checked_redeem_with': violated constraint
# error: constraint declared here evaluated to False
from context_outcome_receiver_support import checked_redeem_with, MissingBorrow, MissingUnary, Positive, Label, Show, Next
from fp.algebra import ResultFamily
from fp.data import Result

def main():
    _ = checked_redeem_with[ResultFamily[String]](ResultFamily[String].pure(3),MissingUnary[Int,Result[String,String]](),Next[String]())
