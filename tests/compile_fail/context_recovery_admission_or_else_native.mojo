# error: no matching method in call to 'or_else'
from fp.functions import pipeline
from fp.data import Result, Err
from context_recovery_admission_support import Policy, MissingUnary, MissingBorrow, MissingEffect, RaiseBorrow, RaisePredicate
from context_error_capability_support import recover, effect, choose, observe, observe_effect, Value, Effect, Predicate, BorrowValue, BorrowEffect

def main():
    _=pipeline[Policy[False]](Result[Int,String](Err(String("old")))).or_else(effect)
