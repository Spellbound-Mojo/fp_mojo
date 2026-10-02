"""Forwarding preserves borrowed inputs, move-only results/errors and callback ownership."""
from fp.data import attempt, raise_on_err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Counts(Copyable):
    var inputs: ArcPointer[Int]
    var outputs: ArcPointer[Int]
    var errors: ArcPointer[Int]
    var captures: ArcPointer[Int]
    var copies: ArcPointer[Int]
    var calls: ArcPointer[Int]

@fieldwise_init
struct Input(Copyable):
    var value: Int
    var counts: Counts
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.counts = copy.counts.copy()
        self.counts.copies[] += 1
    def __deinit__(deinit self): self.counts.inputs[] += 1

@fieldwise_init
struct AttemptForwardingToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Failure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise_1_0_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 103 + 1 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_1_0_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 103 + 1 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_1_1_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 103 + 1 * repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_1_1_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 103 + 1 * repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_0_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input, second: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left, right)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left, right)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 107 + 2 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(right.value, 4 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_0_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input, second: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left, right)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left, right)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 107 + 2 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(right.value, 4 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_1_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input, second: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left^, right)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left^, right)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 107 + 2 * repetition)
        assert_equal(right.value, 4 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_1_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input, second: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left^, right)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left^, right)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 107 + 2 * repetition)
        assert_equal(right.value, 4 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_2_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input, var second: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left, right^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left, right^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 107 + 2 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_2_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(first: Input, var second: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left, right^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left, right^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 107 + 2 * repetition)
        assert_equal(left.value, 3 + repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_3_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input, var second: Input) raises Failure {var state^, counts, fail} -> AttemptForwardingToken:
        counts.calls[] += 1
        if fail: raise Failure(42, counts.errors)
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, left^, right^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(left^, right^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 107 + 2 * repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def exercise_2_3_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptForwardingToken(100, counts.captures)
    def target(var first: Input, var second: Input) {var state^, counts} -> AttemptForwardingToken:
        counts.calls[] += 1
        return AttemptForwardingToken(state.value + first.value + second.value, counts.outputs)
    for repetition in range(2):
        var left = Input(3 + repetition, counts.copy())
        var right = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, left^, right^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(left^, right^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 107 + 2 * repetition)
        assert_equal(counts.copies[], 0)
    assert_equal(counts.calls[], 2)

def main() raises:
    for library in range(2):
        for fail in range(2):
            var counts_1_0_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_0_0(Bool(library), Bool(fail), counts_1_0_0)
            assert_equal(counts_1_0_0.inputs[], 2)
            assert_equal(counts_1_0_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_0_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_0_0.captures[], 1)
            assert_equal(counts_1_0_0.copies[], 0)
            assert_equal(counts_1_0_0.calls[], 2)
            var counts_1_0_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_0_1(Bool(library), Bool(fail), counts_1_0_1)
            assert_equal(counts_1_0_1.inputs[], 2)
            assert_equal(counts_1_0_1.outputs[], 2)
            assert_equal(counts_1_0_1.errors[], 0)
            assert_equal(counts_1_0_1.captures[], 1)
            assert_equal(counts_1_0_1.copies[], 0)
            assert_equal(counts_1_0_1.calls[], 2)
            var counts_1_1_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_1_0(Bool(library), Bool(fail), counts_1_1_0)
            assert_equal(counts_1_1_0.inputs[], 2)
            assert_equal(counts_1_1_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_1_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_1_0.captures[], 1)
            assert_equal(counts_1_1_0.copies[], 0)
            assert_equal(counts_1_1_0.calls[], 2)
            var counts_1_1_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_1_1(Bool(library), Bool(fail), counts_1_1_1)
            assert_equal(counts_1_1_1.inputs[], 2)
            assert_equal(counts_1_1_1.outputs[], 2)
            assert_equal(counts_1_1_1.errors[], 0)
            assert_equal(counts_1_1_1.captures[], 1)
            assert_equal(counts_1_1_1.copies[], 0)
            assert_equal(counts_1_1_1.calls[], 2)
            var counts_2_0_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_0_0(Bool(library), Bool(fail), counts_2_0_0)
            assert_equal(counts_2_0_0.inputs[], 4)
            assert_equal(counts_2_0_0.outputs[], 0 if fail else 2)
            assert_equal(counts_2_0_0.errors[], 2 if fail else 0)
            assert_equal(counts_2_0_0.captures[], 1)
            assert_equal(counts_2_0_0.copies[], 0)
            assert_equal(counts_2_0_0.calls[], 2)
            var counts_2_0_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_0_1(Bool(library), Bool(fail), counts_2_0_1)
            assert_equal(counts_2_0_1.inputs[], 4)
            assert_equal(counts_2_0_1.outputs[], 2)
            assert_equal(counts_2_0_1.errors[], 0)
            assert_equal(counts_2_0_1.captures[], 1)
            assert_equal(counts_2_0_1.copies[], 0)
            assert_equal(counts_2_0_1.calls[], 2)
            var counts_2_1_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_1_0(Bool(library), Bool(fail), counts_2_1_0)
            assert_equal(counts_2_1_0.inputs[], 4)
            assert_equal(counts_2_1_0.outputs[], 0 if fail else 2)
            assert_equal(counts_2_1_0.errors[], 2 if fail else 0)
            assert_equal(counts_2_1_0.captures[], 1)
            assert_equal(counts_2_1_0.copies[], 0)
            assert_equal(counts_2_1_0.calls[], 2)
            var counts_2_1_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_1_1(Bool(library), Bool(fail), counts_2_1_1)
            assert_equal(counts_2_1_1.inputs[], 4)
            assert_equal(counts_2_1_1.outputs[], 2)
            assert_equal(counts_2_1_1.errors[], 0)
            assert_equal(counts_2_1_1.captures[], 1)
            assert_equal(counts_2_1_1.copies[], 0)
            assert_equal(counts_2_1_1.calls[], 2)
            var counts_2_2_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_2_0(Bool(library), Bool(fail), counts_2_2_0)
            assert_equal(counts_2_2_0.inputs[], 4)
            assert_equal(counts_2_2_0.outputs[], 0 if fail else 2)
            assert_equal(counts_2_2_0.errors[], 2 if fail else 0)
            assert_equal(counts_2_2_0.captures[], 1)
            assert_equal(counts_2_2_0.copies[], 0)
            assert_equal(counts_2_2_0.calls[], 2)
            var counts_2_2_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_2_1(Bool(library), Bool(fail), counts_2_2_1)
            assert_equal(counts_2_2_1.inputs[], 4)
            assert_equal(counts_2_2_1.outputs[], 2)
            assert_equal(counts_2_2_1.errors[], 0)
            assert_equal(counts_2_2_1.captures[], 1)
            assert_equal(counts_2_2_1.copies[], 0)
            assert_equal(counts_2_2_1.calls[], 2)
            var counts_2_3_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_3_0(Bool(library), Bool(fail), counts_2_3_0)
            assert_equal(counts_2_3_0.inputs[], 4)
            assert_equal(counts_2_3_0.outputs[], 0 if fail else 2)
            assert_equal(counts_2_3_0.errors[], 2 if fail else 0)
            assert_equal(counts_2_3_0.captures[], 1)
            assert_equal(counts_2_3_0.copies[], 0)
            assert_equal(counts_2_3_0.calls[], 2)
            var counts_2_3_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_2_3_1(Bool(library), Bool(fail), counts_2_3_1)
            assert_equal(counts_2_3_1.inputs[], 4)
            assert_equal(counts_2_3_1.outputs[], 2)
            assert_equal(counts_2_3_1.errors[], 0)
            assert_equal(counts_2_3_1.captures[], 1)
            assert_equal(counts_2_3_1.copies[], 0)
            assert_equal(counts_2_3_1.calls[], 2)
