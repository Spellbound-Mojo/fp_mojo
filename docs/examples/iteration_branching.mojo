"""Independent lazy consumers with explicit buffering and abandonment."""
from fp.iteration import partition, Unbounded, BoundedFail, BufferLimitExceeded
from std.iter import next
from fp.data import Result
from std.os import abort


def even(value: Int) -> Bool: return value % 2 == 0

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
        return even(value)
    var branches = partition(predicate, range(5), buffer=Unbounded())
    print("before consuming:", calls)
    print("accepted:", next(branches[0]), next(branches[0]), next(branches[0]))
    print("rejected backlog:", next(branches[1]), next(branches[1]))
    print("classified:", calls)
    var bounded = partition(even, range(5), buffer=capacity_one())
    print("bounded accepted:", describe(next(bounded[0])), describe(next(bounded[0])))
    print(describe(next(bounded[0])))
    print("sibling also failed:", next(bounded[1]).is_err())
    var closed = partition(even, range(5), buffer=capacity_one())
    closed[1].close()
    print("after closing sibling:", describe(next(closed[0])), describe(next(closed[0])), describe(next(closed[0])))
