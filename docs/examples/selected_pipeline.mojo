"""Select native errors once; stored Result errors remain independent."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
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
def even(value: Int) -> Bool: return value % 2 == 0
def as_text(value: Int) -> String: return String(value)

def main() raises:
    # Inspect the whole input, retain odd payloads, then pair each with text.
    var trace = List[Int]()
    def size(values: List[Int]) {ref trace}: trace.append(len(values))
    def record(value: Int) {ref trace}: trace.append(value)
    var pairs = pipeline(List[Int]([1, 2, 3, 4])).tap(size).filter_not(even).tap_each(record).pair_with(as_text).get()
    assert_equal(trace, List[Int]([4, 1, 3]))
    assert_equal(pairs[1][0], 3)
    assert_equal(pairs[1][1], "3")

    # Borrow payloads for effects, then continue in the selected target family.
    def audit(value: Int) -> Optional[String]: return Optional(String(value))
    var audited = pipeline(List[Int]([1, 2, 3, 4])).traverse_tap[OptionalFamily](audit).get()
    assert_equal(audited.value(), List[Int]([1, 2, 3, 4]))
    def available(value: Int) -> Result[Bool, String]: return Ok(value % 2 == 0)
    def count(var values: List[Int]) -> Int: return len(values)
    var selected = pipeline(audited.take()).filter_effect[ResultFamily[String]](available).map(count).get()
    assert_equal(selected._ok().value, 2)

    # Transform optional values inside the effect, then compact the source.
    def optional_double(var value: Int) -> Optional[Optional[Int]]:
        return Optional(Optional(value * 2) if value % 2 == 0 else Optional[Int]())
    var doubled = pipeline(List[Int]([1,2,3,4])).traverse_filter[OptionalFamily](optional_double).get()
    assert_equal(doubled.value(), List[Int]([4,8]))
    def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value,value+10]))
    var expanded = pipeline(List[Int]([1,2])).flat_traverse[OptionalFamily](expand).get()
    assert_equal(expanded.value(), List[Int]([1,11,2,12]))
    _ = pipeline(List[Int]([1,2])).traverse_void[OptionalFamily](optional_double).get()

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
