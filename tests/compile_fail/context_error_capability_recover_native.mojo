# error: no matching method in call to 'recover'
"""Error mapping alone does not authorize selected recover."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import recover

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).recover(recover)
