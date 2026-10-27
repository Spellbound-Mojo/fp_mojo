# error: invalid call to 'tap_err'
"""Observer payload origins must match the stored error's original owner."""
from fp.functions import pipeline
from fp.data import Result,Err
from error_mapping_support import Probe
from context_error_capability_support import BorrowValue

def check(left:List[Int],right:List[Int]):
    comptime Stored=type_of(Span(left))
    comptime Other=type_of(Span(right))
    _=pipeline[Probe[Stored]](Result[Int,Stored](Err(Span(left)))).tap_err(BorrowValue[Other]())

def main():
    check(List[Int]([1]),List[Int]([2]))
