# error: no matching method in call to 'update'
from fp.effects.async_runtime import Ref


def main():
    # An IO keeps its callbacks, so a capturing closure is rejected.
    var step = 2
    def add(var value: Int) {step} -> Int:
        return value + step
    var cell = Ref(1)
    _ = cell.update[Int](add)
