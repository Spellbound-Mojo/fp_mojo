# error: no matching method in call to 'flat_tap_err'
from fp.functions import pipeline
from fp.data import Result, Err
from context_recovery_admission_support import Policy
from context_error_capability_support import observe_effect

def main():
    _=pipeline[Policy[True,False,1]](Result[Int,String](Err(String("old")))).flat_tap_err(observe_effect)
