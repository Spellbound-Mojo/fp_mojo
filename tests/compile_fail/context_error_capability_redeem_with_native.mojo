# error: no matching method in call to 'redeem_with'
"""Error mapping alone does not authorize selected redeem_with."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import changed_increment_effect, changed_effect

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).redeem_with(changed_increment_effect, changed_effect)
