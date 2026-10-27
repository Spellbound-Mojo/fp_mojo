# error: no matching method in call to 'attempt_tap'
"""Error mapping alone does not authorize selected attempt_tap."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import BorrowEffect

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).attempt_tap(BorrowEffect[Result[Int,String]]())
