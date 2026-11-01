# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err, Ok
from error_mapping_support import Probe

def retry(var reason: String) -> Result[Int, String]: return Ok(1)

def main():
    var handler = kleisli[ResultFamily[String]](retry)
    _ = pipeline[Probe[String]](Result[Int, String](Err(String("old")))).or_else(handler).get()
