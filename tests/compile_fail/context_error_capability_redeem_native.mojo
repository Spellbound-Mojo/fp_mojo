# error: no matching method in call to 'redeem'
"""Error mapping alone does not authorize selected redeem."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import increment, recover

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).redeem(increment, recover)
