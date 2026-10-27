# error: no matching method in call to 'tap_err'
from fp.functions import pipeline
from fp.data import Result, Err
from context_recovery_admission_support import Policy, MissingUnary, MissingBorrow, MissingEffect, RaiseBorrow, RaisePredicate
from context_error_capability_support import recover, effect, choose, observe, observe_effect, Value, Effect, Predicate, BorrowValue, BorrowEffect

def main():
    _=pipeline[Policy[True,True]](Result[Int,String](Err(String("old")))).tap_err(RaiseBorrow())
