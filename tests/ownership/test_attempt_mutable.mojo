"""Mutable forwarding preserves mutation, zero copies and exact cleanup across repeated captured calls."""
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
struct AttemptMutableToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct AttemptMutableFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise_0_0_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_0_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_1_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(first: Input, mut second: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_0_1_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(first: Input, mut second: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_0_2_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(var first: Input, mut second: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first^, second)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first^, second)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_0_2_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(var first: Input, mut second: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first^, second)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first^, second)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_0_3_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, second: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (4 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 4 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_3_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, second: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (4 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 4 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_4_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, var second: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (4 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_4_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, var second: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (4 + repetition))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_0_5_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, mut second: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_0_5_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, mut second: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (3 * (4 + repetition)))
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_0_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_0_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_1_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(first: Input, mut second: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_1_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(first: Input, mut second: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_2_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(var first: Input, mut second: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first^, second, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first^, second, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_2_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(var first: Input, mut second: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first^, second, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first^, second, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (3 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_3_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, second: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (4 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 4 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_3_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, second: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (4 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 4 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_4_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, var second: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second^, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second^, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (4 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_4_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, var second: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second^, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second^, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (4 + repetition) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
    assert_equal(counts.calls[], 2)


def exercise_1_5_0(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, mut second: Input, /, var **values: Input) raises AttemptMutableFailure {var state^, counts, fail} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        second.value *= 3
        if fail: raise AttemptMutableFailure(42, counts.errors)
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed = -1
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            try:
                var output = raise_on_err(result^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try:
                var output = target(first, second, first=keyword_a^, function=keyword_b^)
                observed = output.value
            except error:
                caught = True
                assert_equal(error.code, 42)
        assert_equal(caught, fail)
        assert_equal(observed, -1 if fail else 100 + 10 * (13 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def exercise_1_5_1(library: Bool, fail: Bool, counts: Counts) raises:
    var state = AttemptMutableToken(100, counts.captures)
    def target(mut first: Input, mut second: Input, /, var **values: Input) {var state^, counts} -> AttemptMutableToken:
        counts.calls[] += 1
        first.value += 10
        second.value *= 3
        var total = state.value + 10 * first.value + 100 * second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value.value
        return AttemptMutableToken(total, counts.outputs)
    for repetition in range(2):
        var first = Input(3 + repetition, counts.copy())
        var second = Input(4 + repetition, counts.copy())
        var keyword_a = Input(5 + repetition, counts.copy())
        var keyword_b = Input(6 + repetition, counts.copy())
        var caught = False
        var observed: Int
        if library:
            var result = attempt(target, first, second, first=keyword_a^, function=keyword_b^)
            var output = raise_on_err(result^)
            observed = output.value
        else:
            var output = target(first, second, first=keyword_a^, function=keyword_b^)
            observed = output.value
        assert_equal(caught, False)
        assert_equal(observed, 100 + 10 * (13 + repetition) + 100 * (3 * (4 + repetition)) + 73 + 13 * repetition)
        assert_equal(counts.copies[], 0)
        assert_equal(first.value, 13 + repetition)
        assert_equal(second.value, 3 * (4 + repetition))
    assert_equal(counts.calls[], 2)


def main() raises:
    for library in range(2):
        for fail in range(2):
            var counts_0_0_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_0_0(Bool(library), Bool(fail), counts_0_0_0)
            assert_equal(counts_0_0_0.inputs[], 2)
            assert_equal(counts_0_0_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_0_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_0_0.captures[], 1)
            assert_equal(counts_0_0_0.copies[], 0)
            assert_equal(counts_0_0_0.calls[], 2)
            var counts_0_0_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_0_1(Bool(library), Bool(fail), counts_0_0_1)
            assert_equal(counts_0_0_1.inputs[], 2)
            assert_equal(counts_0_0_1.outputs[], 2)
            assert_equal(counts_0_0_1.errors[], 0)
            assert_equal(counts_0_0_1.captures[], 1)
            assert_equal(counts_0_0_1.copies[], 0)
            assert_equal(counts_0_0_1.calls[], 2)
            var counts_0_1_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_1_0(Bool(library), Bool(fail), counts_0_1_0)
            assert_equal(counts_0_1_0.inputs[], 4)
            assert_equal(counts_0_1_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_1_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_1_0.captures[], 1)
            assert_equal(counts_0_1_0.copies[], 0)
            assert_equal(counts_0_1_0.calls[], 2)
            var counts_0_1_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_1_1(Bool(library), Bool(fail), counts_0_1_1)
            assert_equal(counts_0_1_1.inputs[], 4)
            assert_equal(counts_0_1_1.outputs[], 2)
            assert_equal(counts_0_1_1.errors[], 0)
            assert_equal(counts_0_1_1.captures[], 1)
            assert_equal(counts_0_1_1.copies[], 0)
            assert_equal(counts_0_1_1.calls[], 2)
            var counts_0_2_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_2_0(Bool(library), Bool(fail), counts_0_2_0)
            assert_equal(counts_0_2_0.inputs[], 4)
            assert_equal(counts_0_2_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_2_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_2_0.captures[], 1)
            assert_equal(counts_0_2_0.copies[], 0)
            assert_equal(counts_0_2_0.calls[], 2)
            var counts_0_2_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_2_1(Bool(library), Bool(fail), counts_0_2_1)
            assert_equal(counts_0_2_1.inputs[], 4)
            assert_equal(counts_0_2_1.outputs[], 2)
            assert_equal(counts_0_2_1.errors[], 0)
            assert_equal(counts_0_2_1.captures[], 1)
            assert_equal(counts_0_2_1.copies[], 0)
            assert_equal(counts_0_2_1.calls[], 2)
            var counts_0_3_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_3_0(Bool(library), Bool(fail), counts_0_3_0)
            assert_equal(counts_0_3_0.inputs[], 4)
            assert_equal(counts_0_3_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_3_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_3_0.captures[], 1)
            assert_equal(counts_0_3_0.copies[], 0)
            assert_equal(counts_0_3_0.calls[], 2)
            var counts_0_3_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_3_1(Bool(library), Bool(fail), counts_0_3_1)
            assert_equal(counts_0_3_1.inputs[], 4)
            assert_equal(counts_0_3_1.outputs[], 2)
            assert_equal(counts_0_3_1.errors[], 0)
            assert_equal(counts_0_3_1.captures[], 1)
            assert_equal(counts_0_3_1.copies[], 0)
            assert_equal(counts_0_3_1.calls[], 2)
            var counts_0_4_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_4_0(Bool(library), Bool(fail), counts_0_4_0)
            assert_equal(counts_0_4_0.inputs[], 4)
            assert_equal(counts_0_4_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_4_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_4_0.captures[], 1)
            assert_equal(counts_0_4_0.copies[], 0)
            assert_equal(counts_0_4_0.calls[], 2)
            var counts_0_4_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_4_1(Bool(library), Bool(fail), counts_0_4_1)
            assert_equal(counts_0_4_1.inputs[], 4)
            assert_equal(counts_0_4_1.outputs[], 2)
            assert_equal(counts_0_4_1.errors[], 0)
            assert_equal(counts_0_4_1.captures[], 1)
            assert_equal(counts_0_4_1.copies[], 0)
            assert_equal(counts_0_4_1.calls[], 2)
            var counts_0_5_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_5_0(Bool(library), Bool(fail), counts_0_5_0)
            assert_equal(counts_0_5_0.inputs[], 4)
            assert_equal(counts_0_5_0.outputs[], 0 if fail else 2)
            assert_equal(counts_0_5_0.errors[], 2 if fail else 0)
            assert_equal(counts_0_5_0.captures[], 1)
            assert_equal(counts_0_5_0.copies[], 0)
            assert_equal(counts_0_5_0.calls[], 2)
            var counts_0_5_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_0_5_1(Bool(library), Bool(fail), counts_0_5_1)
            assert_equal(counts_0_5_1.inputs[], 4)
            assert_equal(counts_0_5_1.outputs[], 2)
            assert_equal(counts_0_5_1.errors[], 0)
            assert_equal(counts_0_5_1.captures[], 1)
            assert_equal(counts_0_5_1.copies[], 0)
            assert_equal(counts_0_5_1.calls[], 2)
            var counts_1_0_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_0_0(Bool(library), Bool(fail), counts_1_0_0)
            assert_equal(counts_1_0_0.inputs[], 6)
            assert_equal(counts_1_0_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_0_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_0_0.captures[], 1)
            assert_equal(counts_1_0_0.copies[], 0)
            assert_equal(counts_1_0_0.calls[], 2)
            var counts_1_0_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_0_1(Bool(library), Bool(fail), counts_1_0_1)
            assert_equal(counts_1_0_1.inputs[], 6)
            assert_equal(counts_1_0_1.outputs[], 2)
            assert_equal(counts_1_0_1.errors[], 0)
            assert_equal(counts_1_0_1.captures[], 1)
            assert_equal(counts_1_0_1.copies[], 0)
            assert_equal(counts_1_0_1.calls[], 2)
            var counts_1_1_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_1_0(Bool(library), Bool(fail), counts_1_1_0)
            assert_equal(counts_1_1_0.inputs[], 8)
            assert_equal(counts_1_1_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_1_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_1_0.captures[], 1)
            assert_equal(counts_1_1_0.copies[], 0)
            assert_equal(counts_1_1_0.calls[], 2)
            var counts_1_1_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_1_1(Bool(library), Bool(fail), counts_1_1_1)
            assert_equal(counts_1_1_1.inputs[], 8)
            assert_equal(counts_1_1_1.outputs[], 2)
            assert_equal(counts_1_1_1.errors[], 0)
            assert_equal(counts_1_1_1.captures[], 1)
            assert_equal(counts_1_1_1.copies[], 0)
            assert_equal(counts_1_1_1.calls[], 2)
            var counts_1_2_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_2_0(Bool(library), Bool(fail), counts_1_2_0)
            assert_equal(counts_1_2_0.inputs[], 8)
            assert_equal(counts_1_2_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_2_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_2_0.captures[], 1)
            assert_equal(counts_1_2_0.copies[], 0)
            assert_equal(counts_1_2_0.calls[], 2)
            var counts_1_2_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_2_1(Bool(library), Bool(fail), counts_1_2_1)
            assert_equal(counts_1_2_1.inputs[], 8)
            assert_equal(counts_1_2_1.outputs[], 2)
            assert_equal(counts_1_2_1.errors[], 0)
            assert_equal(counts_1_2_1.captures[], 1)
            assert_equal(counts_1_2_1.copies[], 0)
            assert_equal(counts_1_2_1.calls[], 2)
            var counts_1_3_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_3_0(Bool(library), Bool(fail), counts_1_3_0)
            assert_equal(counts_1_3_0.inputs[], 8)
            assert_equal(counts_1_3_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_3_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_3_0.captures[], 1)
            assert_equal(counts_1_3_0.copies[], 0)
            assert_equal(counts_1_3_0.calls[], 2)
            var counts_1_3_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_3_1(Bool(library), Bool(fail), counts_1_3_1)
            assert_equal(counts_1_3_1.inputs[], 8)
            assert_equal(counts_1_3_1.outputs[], 2)
            assert_equal(counts_1_3_1.errors[], 0)
            assert_equal(counts_1_3_1.captures[], 1)
            assert_equal(counts_1_3_1.copies[], 0)
            assert_equal(counts_1_3_1.calls[], 2)
            var counts_1_4_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_4_0(Bool(library), Bool(fail), counts_1_4_0)
            assert_equal(counts_1_4_0.inputs[], 8)
            assert_equal(counts_1_4_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_4_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_4_0.captures[], 1)
            assert_equal(counts_1_4_0.copies[], 0)
            assert_equal(counts_1_4_0.calls[], 2)
            var counts_1_4_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_4_1(Bool(library), Bool(fail), counts_1_4_1)
            assert_equal(counts_1_4_1.inputs[], 8)
            assert_equal(counts_1_4_1.outputs[], 2)
            assert_equal(counts_1_4_1.errors[], 0)
            assert_equal(counts_1_4_1.captures[], 1)
            assert_equal(counts_1_4_1.copies[], 0)
            assert_equal(counts_1_4_1.calls[], 2)
            var counts_1_5_0 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_5_0(Bool(library), Bool(fail), counts_1_5_0)
            assert_equal(counts_1_5_0.inputs[], 8)
            assert_equal(counts_1_5_0.outputs[], 0 if fail else 2)
            assert_equal(counts_1_5_0.errors[], 2 if fail else 0)
            assert_equal(counts_1_5_0.captures[], 1)
            assert_equal(counts_1_5_0.copies[], 0)
            assert_equal(counts_1_5_0.calls[], 2)
            var counts_1_5_1 = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0), ArcPointer(0))
            exercise_1_5_1(Bool(library), Bool(fail), counts_1_5_1)
            assert_equal(counts_1_5_1.inputs[], 8)
            assert_equal(counts_1_5_1.outputs[], 2)
            assert_equal(counts_1_5_1.errors[], 0)
            assert_equal(counts_1_5_1.captures[], 1)
            assert_equal(counts_1_5_1.copies[], 0)
            assert_equal(counts_1_5_1.calls[], 2)
