# error: no matching method in call to 'tap_err'
"""Error mapping alone does not authorize selected tap_err."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import observe

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).tap_err(observe)
