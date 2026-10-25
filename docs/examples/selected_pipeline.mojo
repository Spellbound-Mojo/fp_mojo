"""Select native errors once; stored Result errors remain independent."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct PipelineProcessingFailure(Movable):
    var code: Int

def process(var value: Int) raises PipelineProcessingFailure -> Int:
    if value < 0: raise PipelineProcessingFailure(90)
    return value * 2

def accepted(value: Int) -> Bool: return value < 10
def invalid(value: Int) -> String: return String("too large")
def length(var message: String) -> Int: return message.byte_length()
def recover(var code: Int) -> Result[Int, String]: return Ok(code)
def double(var value: Int) -> Int: return value * 2

def main() raises:
    var checked: Result[Int, String]
    try:
        checked = pipeline(Result[Int, String](Ok(4))).raising[PipelineProcessingFailure]().map(process).ensure(accepted, invalid).get()
    except _: raise Error("unexpected processing failure")
    assert_equal(checked._ok().value, 8)
    print("accepted:", checked._ok().value)

    # Changing the stored error also updates the selected Result family.
    var recovered = pipeline(Result[Int, String](Err(String("bad")))).map_err(length).or_else(recover).map(double).get()
    assert_equal(recovered._ok().value, 6)
    print("recovered:", recovered._ok().value)

    var code = 0
    try:
        _ = pipeline(Result[Int, String](Ok(-1))).raising[PipelineProcessingFailure]().map(process).get()
    except error: code = error.code
    assert_equal(code, 90)
    print("raised:", code)
