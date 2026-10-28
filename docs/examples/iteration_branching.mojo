"""Independent lazy consumers with explicit buffering and abandonment."""
from fp.iteration import iterated, partition, partition_map, Unbounded, BoundedFail, BufferLimitExceeded
from fp.functions import partial
from std.iter import next
from fp.data import Result, Ok, Err
from std.os import abort


def divisible(divisor: Int, value: Int) -> Bool: return value % divisor == 0

def classify(limit: Int, value: Int) -> Result[Int, String]:
    if value < limit: return Ok(value)
    return Err(String(value))

def capacity_one() -> BoundedFail:
    try: return BoundedFail(1)
    except: abort("one is a valid capacity")


def describe(result: Result[Int,BufferLimitExceeded]) -> String:
    def success(value: Int) -> String: return String(value)
    def failure(error: BufferLimitExceeded) -> String:
        return "overflow(branch=" + String(error.branch) + ",capacity=" + String(error.capacity) + ")"
    return result.fold(success, failure)


def main() raises:
    var calls = 0
    def predicate(value: Int) {mut calls} -> Bool:
        calls += 1
        return divisible(2, value)
    var branches = partition(predicate, range(5), buffer=Unbounded())
    print("before consuming:", calls)
    print("accepted:", next(branches[0]), next(branches[0]), next(branches[0]))
    print("rejected backlog:", next(branches[1]), next(branches[1]))
    print("classified:", calls)
    var evens = partial(divisible, 2)
    var bounded = partition(evens, range(5), buffer=capacity_one())
    print("bounded accepted:", describe(next(bounded[0])), describe(next(bounded[0])))
    print(describe(next(bounded[0])))
    print("sibling also failed:", next(bounded[1]).is_err())
    var closed = partition(evens, range(5), buffer=capacity_one())
    closed[1].close()
    print("after closing sibling:", describe(next(closed[0])), describe(next(closed[0])), describe(next(closed[0])))
    var route = partial(classify, 2)
    var classified = partition_map(route, range(4), buffer=Unbounded())
    print("classified:", next(classified[0]), next(classified[1]))
    var again = iterated(range(2, 4)).partition_map(route, buffer=Unbounded())
    print("reused classifier:", next(again[1]))
