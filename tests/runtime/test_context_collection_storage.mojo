"""Qualify native storage transfer independently of callback admission."""
from std.collections import Deque, StringDict
from std.hash import default_comp_time_hasher
from std.memory import ArcPointer
from std.testing import assert_equal
from fp._internal.native_collections import _empty_deque_like, _take_string_dict, _string_dict_from_native
from fp.functions import pipeline_values

@fieldwise_init
struct StorageItem(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def main() raises:
    var source = Deque[Int](capacity=32, min_capacity=8, maxlen=3, shrink=False)
    source.append(7)
    var changed = _empty_deque_like[Int, String](source)
    assert_equal(changed._capacity, source._capacity)
    assert_equal(changed._min_capacity, 8)
    assert_equal(changed._maxlen, 3)
    assert_equal(changed._shrink, False)
    assert_equal(len(source), 1)
    assert_equal(len(changed), 0)
    changed.append("a")
    changed.append("b")
    changed.append("c")
    changed.append("d")
    assert_equal(changed.popleft(), "b")
    var growing = Deque[Int](capacity=32, min_capacity=8, shrink=True)
    var same = _empty_deque_like[Int, Int](growing)
    assert_equal(same._capacity, growing._capacity)
    assert_equal(same._min_capacity, growing._min_capacity)
    assert_equal(same._maxlen, growing._maxlen)
    assert_equal(same._shrink, growing._shrink)
    transfer()
    failure()
    origins(List[Int]([3, 5]))

def transfer() raises:
    var drops = ArcPointer(0)
    var source = StringDict[StorageItem]()
    source["second"] = StorageItem(2, drops)
    source["first"] = StorageItem(1, drops)
    var native = _take_string_dict(source^)
    comptime assert type_of(native) == Dict[String, StorageItem, default_comp_time_hasher]
    assert_equal(drops[], 0)
    var roundtrip = _string_dict_from_native(native^)
    assert_equal(drops[], 0)
    var restored = _take_string_dict(roundtrip^)
    var order = List[String]()
    def record(var key: String, var value: StorageItem) {ref order}:
        order.append(key^)
    for var entry in restored.take_items(): entry^.deinit_with(record)
    assert_equal(order, ["second", "first"])
    _ = restored^
    assert_equal(drops[], 2)
    var empty = StringDict[StorageItem]()
    assert_equal(len(_string_dict_from_native(_take_string_dict(empty^))), 0)

def failure() raises:
    var input_drops = ArcPointer(0)
    var output_drops = ArcPointer(0)
    var source = StringDict[StorageItem]()
    source["a"] = StorageItem(1, input_drops)
    source["b"] = StorageItem(2, input_drops)
    source["c"] = StorageItem(3, input_drops)
    def checked(var value: StorageItem) raises Int {output_drops} -> StorageItem:
        if value.value == 2: raise 702
        return StorageItem(value.value, output_drops)
    var code = 0
    try: _ = pipeline_values(source^).raising[Int]().map(checked).get()
    except error: code = error
    assert_equal(code, 702)
    assert_equal(input_drops[], 3)
    assert_equal(output_drops[], 1)

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var source = StringDict[View]()
    source["view"] = Span(owner)
    var result = _string_dict_from_native(_take_string_dict(source^))
    comptime assert type_of(result) == StringDict[View]
    assert_equal(result["view"].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
