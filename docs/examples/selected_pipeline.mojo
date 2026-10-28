"""Select native errors once; stored Result errors remain independent."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err, ok, err
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
    # A stored native pointer uses the same selected call syntax.
    var transform: def(var Int) thin -> Int = double
    assert_equal(pipeline(Optional(3)).map(transform).get().value(), 6)
    # Inspect the whole input, retain odd payloads, then pair each with text.
    var trace = List[Int]()
    def size(values: List[Int]) {ref trace}: trace.append(len(values))
    def record(value: Int) {ref trace}: trace.append(value)
    var pairs = pipeline[Int]([1, 2, 3, 4]).tap(size).filter_not(even).tap_each(record).pair_with(as_text).get()
    assert_equal(trace, List[Int]([4, 1, 3]))
    assert_equal(pairs[1][0], 3)
    assert_equal(pairs[1][1], "3")

    # Borrow payloads for effects, then continue in the selected target family.
    def audit(value: Int) -> Optional[String]: return Optional(String(value))
    var audited = pipeline[Int]([1, 2, 3, 4]).traverse_tap(audit).get()
    assert_equal(audited.value(), List[Int]([1, 2, 3, 4]))
    def available(value: Int) -> Result[Bool, String]: return Ok(value % 2 == 0)
    def count(var values: List[Int]) -> Int: return len(values)
    var selected = pipeline(audited.take()).filter_effect(available).map(count).get_or(0)
    assert_equal(selected, 2)

    # Transform optional values inside the effect, then compact the source.
    def optional_double(var value: Int) -> Optional[Optional[Int]]:
        return Optional(Optional(value * 2) if value % 2 == 0 else Optional[Int]())
    var doubled = pipeline[Int]([1,2,3,4]).traverse_filter(optional_double).get()
    assert_equal(doubled.value(), List[Int]([4,8]))
    def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value,value+10]))
    var expanded = pipeline[Int]([1,2]).flat_traverse(expand).get()
    assert_equal(expanded.value(), List[Int]([1,11,2,12]))
    _ = pipeline[Int]([1,2]).traverse_void(optional_double).get()

    # Reductions infer numeric types and select the resulting carrier family.
    assert_equal(pipeline(range(4)).sum_by(double).get(), 12)
    assert_equal(pipeline[Int]([1,2,3]).max_by(as_text).get().value(), 3)
    var compacted = pipeline[Optional[Int]]([Optional(1),Optional[Int](),Optional(3)]).compact().tuple_right(String("kept")).get()
    assert_equal(compacted[1][0], 3)
    assert_equal(compacted[1][1], "kept")
    def present() -> Optional[Int]: return Optional(10)
    def absent() -> Optional[Int]: return None
    assert_equal(pipeline(Optional(True)).if_effect(present, absent).get().value(), 10)
    def validate(var value: Int) -> Result[Int,List[String]]:
        if value < 0: return Err(List[String]([String(value)]))
        return Ok(value)
    var errors = pipeline[Int]([-1,2,-3]).par_traverse(validate).swap().to_optional()
    assert_equal(errors.value(), List[String](["-1","-3"]))

    var checked: Int
    try:
        checked = pipeline(ok[String](4)).raising[PipelineProcessingFailure]().map(process).ensure(accepted, invalid).get_or(0)
    except _: raise Error("unexpected processing failure")
    assert_equal(checked, 8)
    print("accepted:", checked)

    # Changing the stored error also updates the selected Result family.
    var recovered = pipeline(err[Int]("bad")).map_err(length).or_else(recover).map(double).get_or(0)
    assert_equal(recovered, 6)
    print("recovered:", recovered)

    var code = 0
    try:
        _ = pipeline(ok[String](-1)).raising[PipelineProcessingFailure]().map(process).get()
    except error: code = error.code
    assert_equal(code, 90)
    print("raised:", code)
