# error: no matching method in call to 'redeem_with'
"""Error mapping alone does not authorize selected redeem_with."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import Effect

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).redeem_with(Effect[Int,String](), Effect[String,String]())
