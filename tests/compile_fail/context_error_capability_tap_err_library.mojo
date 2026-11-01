# error: no matching method in call to 'tap_err'
"""A mapping policy that rejects observation cannot fall back to intrinsic Result."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import BorrowValue

def main():
    _ = pipeline[Probe[String,1]](Result[Int,String](Err(String("old")))).tap_err(BorrowValue[String]())
