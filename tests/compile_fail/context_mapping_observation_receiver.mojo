# error: no matching method in call to 'tap_err'
"""A call signature without an invocable receiver is rejected."""
from fp.functions import pipeline
from fp.data import Result,Err
from error_mapping_support import Probe
from context_recovery_admission_support import MissingBorrow

def main():
    _=pipeline[Probe[String]](Result[Int,String](Err(String("stored")))).tap_err(MissingBorrow())
