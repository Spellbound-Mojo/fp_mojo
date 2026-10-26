"""Dictionary value selection follows changed payloads without copying keys."""
from std.collections import StringDict
from std.hash import default_comp_time_hasher
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.algebra import Functor, MapContract
from fp.callables import UnaryContract
from fp.functions import pipeline, pipeline_values, Pipeline, Identity
from fp.iteration import collect_list
from test_container_map import ContainerMapItem, ContainerMapKey, ContainerMapFailure

def label(var value: Int) -> String: return String(value)
def size(var value: String) -> Int: return value.byte_length()
def positive(value: Int) -> Bool: return value > 0
def present(var value: Int) -> Optional[String]:
    return Optional(String(value)) if value > 0 else None
def borrowed_size(value: String) -> Int: return value.byte_length()
def pair_size(var value: Tuple[String, Int]) -> Int: return value[1]
def first(var value: Tuple[String, Int]) -> String: return value[0]
def whole(var value: Dict[String, Int]) -> Int: return len(value)

def forward[I: Functor, V: Movable & Deinitable, E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var stage: Pipeline[I, V, E], var function: F
) raises MapContract[I, V, F].Error -> Pipeline[MapContract[I, V, F].Family, MapContract[I, V, F].Out, E] where MapContract[I, V, F].Compatible:
    return stage^.map(function^)

def main() raises:
    var values = Dict[String, Int, default_comp_time_hasher]()
    values["b"] = 42
    values["a"] = 0
    values["c"] = 7
    var stage = pipeline_values(values^).map(label).map(size).filter(positive).filter_not(negative)
    var result = forward(stage^, Identity[Int]()).get()
    comptime assert type_of(result) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(result["b"], 2)
    assert_equal(collect_list(result^), ["b", "a", "c"])
    var selected = Dict[String, Int]()
    selected["keep"] = 42
    selected["drop"] = -1
    var kept = pipeline_values(selected^).filter_map(present).pair_with(borrowed_size).map(pair_size).get()
    assert_equal(len(kept), 1)
    assert_equal(kept["keep"], 2)
    var nested = StringDict[Optional[Int]]()
    nested["keep"] = Optional(42)
    nested["drop"] = None
    var compacted = pipeline_values(nested^).compact().map(label).tuple_right(9).map(first).get()
    comptime assert type_of(compacted) == StringDict[String]
    assert_equal(compacted["keep"], "42")
    assert_equal(len(compacted), 1)
    var empty = StringDict[Int]()
    var empty_result = pipeline_values(empty^).filter_map(present).map(size).get()
    comptime assert type_of(empty_result) == StringDict[Int]
    assert_equal(len(empty_result), 0)
    var original = Dict[String, Int]()
    original["x"] = 1
    assert_equal(pipeline(original^).map(whole).get(), 1)
    ownership()
    origins(List[Int]([11, 12]))

def negative(value: Int) -> Bool: return value < 0

def ownership() raises:
    var keys = ArcPointer(0)
    var payloads = ArcPointer(0)
    var values = Dict[ContainerMapKey, ContainerMapItem]()
    values[ContainerMapKey(1, keys)] = ContainerMapItem(1, payloads)
    values[ContainerMapKey(2, keys)] = ContainerMapItem(2, payloads)
    values[ContainerMapKey(3, keys)] = ContainerMapItem(3, payloads)
    var code = 0
    try:
        _ = pipeline_values(values^).raising[ContainerMapFailure]().map(checked).map(label).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        code = error.at
    assert_equal(code, 2)
    assert_equal(keys[], 3)
    assert_equal(payloads[], 3)
    var other = StringDict[ContainerMapItem]()
    other["x"] = ContainerMapItem(1, payloads)
    var mapped = pipeline_values(other^).map(extract).map(label).get()
    assert_equal(mapped["x"], "1")
    assert_equal(payloads[], 4)

def checked(var value: ContainerMapItem) raises ContainerMapFailure -> Int:
    if value.value == 2: raise ContainerMapFailure(2)
    return value.value

def extract(var value: ContainerMapItem) -> Int: return value.value

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    def view(var value: Int) {owner} -> View: return Span(owner)
    var values = Dict[String, Int]()
    values["view"] = 1
    var mapped = pipeline_values(values^).map(view)
    var result = forward(mapped^, Identity[View]()).get()
    comptime assert type_of(result) == Dict[String, View]
    assert_equal(result["view"].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
