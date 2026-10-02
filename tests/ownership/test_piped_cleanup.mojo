"""Chained pipelines move each value once and release it exactly once, also on failure."""
from fp.functions import piped
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct PipedResource(Movable):
    var value: Int
    var drops: ArcPointer[Int]

    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct PipedFault(Movable, Writable):
    var code: Int


def bump(var resource: PipedResource) -> PipedResource:
    resource.value += 1
    return resource^


def reject(var resource: PipedResource) raises PipedFault -> PipedResource:
    raise PipedFault(resource.value)


def main() raises:
    var drops = ArcPointer(0)
    # Move-only values pass through without copies; one value lives at a time.
    var kept = piped(PipedResource(1, drops)).then(bump).then(bump).then(bump).get()
    assert_equal(kept.value, 4)
    assert_equal(drops[], 0)
    _ = kept^
    assert_equal(drops[], 1)

    # A raising stage owns the value it received; nothing is left behind.
    var code = 0
    try:
        _ = piped(PipedResource(10, drops)).then(bump).then(reject).then(bump).get()
    except error:
        code = error.code
    assert_equal(code, 11)
    assert_equal(drops[], 2)

    # Abandoning a chain releases its value.
    var chain = piped(PipedResource(20, drops)).then(bump)
    _ = chain^
    assert_equal(drops[], 3)
    print("piped cleanup: moved once, released once")
