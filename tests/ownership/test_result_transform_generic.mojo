"""Native-Variant reference selection, copy counters, repeated captures and cleanup."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.utils import Variant
from std.memory import ArcPointer
from std.testing import assert_equal

def map_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](var value: Result[T, E], callback: F) -> Result[U, E]:
    return map[ResultFamily[type_of(value).Error]](callback, value^)

def map_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](var value: Result[T, E], callback: F) -> Result[U, E]:
    return map_pure1(value^, callback)

def map_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return map[ResultFamily[type_of(value).Error], X=X](callback, value^)

def map_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return map_raising1[X=X](value^, callback)

def map_err_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> U](var value: Result[T, E], callback: F) -> Result[T, U]:
    return value^.map_err(callback)

def map_err_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> U](var value: Result[T, E], callback: F) -> Result[T, U]:
    return map_err_pure1(value^, callback)

def map_err_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return value^.map_err[X=X](callback)

def map_err_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return map_err_raising1[X=X](value^, callback)

def and_then_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> Result[U, E]](var value: Result[T, E], callback: F) -> Result[U, E]:
    return flat_map[ResultFamily[type_of(value).Error]](callback, value^)

def and_then_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> Result[U, E]](var value: Result[T, E], callback: F) -> Result[U, E]:
    return and_then_pure1(value^, callback)

def and_then_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return flat_map[ResultFamily[type_of(value).Error], X=X](callback, value^)

def and_then_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return and_then_raising1[X=X](value^, callback)

def or_else_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return value^.or_else(callback)

def or_else_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return or_else_pure1(value^, callback)

def or_else_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> Result[T, U]](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return value^.or_else[X=X](callback)

def or_else_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> Result[T, U]](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return or_else_raising1[X=X](value^, callback)

@fieldwise_init
struct Tracked[tag: Int](Copyable):
    var value: Int
    var drops: ArcPointer[List[Int]]
    var copies: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.drops = copy.drops
        self.copies = copy.copies
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[][Self.tag] += 1

comptime Input = Tracked[0]
comptime Domain = Tracked[1]
comptime Output = Tracked[2]
comptime Translated = Tracked[3]
comptime Fault = Tracked[4]
@fieldwise_init
struct State(Movable):
    var value: Int
    var drops: ArcPointer[List[Int]]
    var copies: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[][5] += 1

def transform_pure(library: Bool, operation: Int, input_ok: Bool, mode: Int,
                            drops: ArcPointer[List[Int]], copies: ArcPointer[Int],
                            trace: ArcPointer[List[Int]]) -> Int:
    # Four owned immutable captures; counters are explicitly borrowed and mutated.
    var state0 = State(10, drops, copies)
    var state1 = State(20, drops, copies)
    var state2 = State(30, drops, copies)
    var state3 = State(40, drops, copies)
    var calls0 = 0
    var calls1 = 0
    var calls2 = 0
    var calls3 = 0
    def mapper(var value: Input) {var state0^, mut calls0, mode, drops, copies, trace} -> Output:
        calls0 += 1
        trace[].append(1000 + 100 * calls0 + value.value)
        return Output(state0.value + value.value, drops, copies)
    def error_mapper(var value: Domain) {var state1^, mut calls1, mode, drops, copies, trace} -> Translated:
        calls1 += 1
        trace[].append(2000 + 100 * calls1 + value.value)
        return Translated(state1.value + value.value, drops, copies)
    def binder(var value: Input) {var state2^, mut calls2, mode, drops, copies, trace} -> Result[Output, Domain]:
        calls2 += 1
        trace[].append(3000 + 100 * calls2 + value.value)
        if mode == 1: return Result[Output, Domain](Err(Domain(state2.value + value.value, drops, copies)))
        return Result[Output, Domain](Ok(Output(state2.value + value.value, drops, copies)))
    def recover(var value: Domain) {var state3^, mut calls3, mode, drops, copies, trace} -> Result[Input, Translated]:
        calls3 += 1
        trace[].append(4000 + 100 * calls3 + value.value)
        if mode == 1: return Result[Input, Translated](Err(Translated(state3.value + value.value, drops, copies)))
        return Result[Input, Translated](Ok(Input(state3.value + value.value, drops, copies)))
    def input_value(value: Input) -> Int: return value.value
    def domain_code(value: Domain) -> Int: return -value.value
    def output_value(value: Output) -> Int: return value.value
    def translated_code(value: Translated) -> Int: return -value.value
    var encoded = 0
    # Reuse the same borrowed callback twice, including its owned capture.
    for iteration in range(2):
        var source = Variant[Ok[Input], Err[Domain]](Ok(Input(7 + iteration, drops, copies))) if input_ok else Variant[Ok[Input], Err[Domain]](Err(Domain(9 + iteration, drops, copies)))
        if library:
            var subject = Result[Input, Domain](source^.unwrap[Ok[Input]]()) if input_ok else Result[Input, Domain](source^.unwrap[Err[Domain]]())
            if operation == 0:
                var result = map_pure2(subject^, mapper)
                encoded += result.fold(output_value, domain_code)
            elif operation == 1:
                var result = map_err_pure2(subject^, error_mapper)
                encoded += result.fold(input_value, translated_code)
            elif operation == 2:
                var result = and_then_pure2(subject^, binder)
                encoded += result.fold(output_value, domain_code)
            else:
                var result = or_else_pure2(subject^, recover)
                encoded += result.fold(input_value, translated_code)
        elif input_ok:
            var value = source^.unwrap[Ok[Input]]().into_payload()
            if operation == 0:
                var result = mapper(value^)
                encoded += result.value
            elif operation == 2:
                var result = binder(value^)
                encoded += result.fold(output_value, domain_code)
            else: encoded += value.value
        else:
            var value = source^.unwrap[Err[Domain]]().into_payload()
            if operation == 1:
                var result = error_mapper(value^)
                encoded -= result.value
            elif operation == 3:
                var result = recover(value^)
                encoded += result.fold(input_value, translated_code)
            else: encoded -= value.value
    return encoded


def transform_raising(library: Bool, operation: Int, input_ok: Bool, mode: Int,
                            drops: ArcPointer[List[Int]], copies: ArcPointer[Int],
                            trace: ArcPointer[List[Int]]) -> Int:
    # Four owned immutable captures; counters are explicitly borrowed and mutated.
    var state0 = State(10, drops, copies)
    var state1 = State(20, drops, copies)
    var state2 = State(30, drops, copies)
    var state3 = State(40, drops, copies)
    var calls0 = 0
    var calls1 = 0
    var calls2 = 0
    var calls3 = 0
    def mapper(var value: Input) raises Fault {var state0^, mut calls0, mode, drops, copies, trace} -> Output:
        calls0 += 1
        trace[].append(1000 + 100 * calls0 + value.value)
        if mode == 2: raise Fault(value.value + 100, drops, copies)
        return Output(state0.value + value.value, drops, copies)
    def error_mapper(var value: Domain) raises Fault {var state1^, mut calls1, mode, drops, copies, trace} -> Translated:
        calls1 += 1
        trace[].append(2000 + 100 * calls1 + value.value)
        if mode == 2: raise Fault(value.value + 200, drops, copies)
        return Translated(state1.value + value.value, drops, copies)
    def binder(var value: Input) raises Fault {var state2^, mut calls2, mode, drops, copies, trace} -> Result[Output, Domain]:
        calls2 += 1
        trace[].append(3000 + 100 * calls2 + value.value)
        if mode == 2: raise Fault(value.value + 300, drops, copies)
        if mode == 1: return Result[Output, Domain](Err(Domain(state2.value + value.value, drops, copies)))
        return Result[Output, Domain](Ok(Output(state2.value + value.value, drops, copies)))
    def recover(var value: Domain) raises Fault {var state3^, mut calls3, mode, drops, copies, trace} -> Result[Input, Translated]:
        calls3 += 1
        trace[].append(4000 + 100 * calls3 + value.value)
        if mode == 2: raise Fault(value.value + 400, drops, copies)
        if mode == 1: return Result[Input, Translated](Err(Translated(state3.value + value.value, drops, copies)))
        return Result[Input, Translated](Ok(Input(state3.value + value.value, drops, copies)))
    def input_value(value: Input) -> Int: return value.value
    def domain_code(value: Domain) -> Int: return -value.value
    def output_value(value: Output) -> Int: return value.value
    def translated_code(value: Translated) -> Int: return -value.value
    var encoded = 0
    # Reuse the same borrowed callback twice, including its owned capture.
    for iteration in range(2):
        var source = Variant[Ok[Input], Err[Domain]](Ok(Input(7 + iteration, drops, copies))) if input_ok else Variant[Ok[Input], Err[Domain]](Err(Domain(9 + iteration, drops, copies)))
        try:
            if library:
                var subject = Result[Input, Domain](source^.unwrap[Ok[Input]]()) if input_ok else Result[Input, Domain](source^.unwrap[Err[Domain]]())
                if operation == 0:
                    var result = map_raising2[X=Fault](subject^, mapper)
                    encoded += result.fold(output_value, domain_code)
                elif operation == 1:
                    var result = map_err_raising2[X=Fault](subject^, error_mapper)
                    encoded += result.fold(input_value, translated_code)
                elif operation == 2:
                    var result = and_then_raising2[X=Fault](subject^, binder)
                    encoded += result.fold(output_value, domain_code)
                else:
                    var result = or_else_raising2[X=Fault](subject^, recover)
                    encoded += result.fold(input_value, translated_code)
            elif input_ok:
                var value = source^.unwrap[Ok[Input]]().into_payload()
                if operation == 0:
                    var result = mapper(value^)
                    encoded += result.value
                elif operation == 2:
                    var result = binder(value^)
                    encoded += result.fold(output_value, domain_code)
                else: encoded += value.value
            else:
                var value = source^.unwrap[Err[Domain]]().into_payload()
                if operation == 1:
                    var result = error_mapper(value^)
                    encoded -= result.value
                elif operation == 3:
                    var result = recover(value^)
                    encoded += result.fold(input_value, translated_code)
                else: encoded -= value.value
        except error:
            comptime assert type_of(error) == Fault
            encoded -= 1000 + error.value
    return encoded

def main() raises:
    comptime for raising in range(2):
        for operation in range(4):
            for input_ok in range(2):
                for mode in range(3):
                    var outputs = List[Int]()
                    var traces = List[List[Int]]()
                    var drop_counts = List[List[Int]]()
                    var active = Bool(input_ok) if operation == 0 or operation == 2 else not Bool(input_ok)
                    for library in range(2):
                        var drops = ArcPointer[List[Int]]([0, 0, 0, 0, 0, 0])
                        var copies = ArcPointer(0)
                        var trace = ArcPointer(List[Int]())
                        comptime if raising:
                            outputs.append(transform_raising(Bool(library), operation, Bool(input_ok), mode, drops, copies, trace))
                        else:
                            outputs.append(transform_pure(Bool(library), operation, Bool(input_ok), mode, drops, copies, trace))
                        assert_equal(copies[], 0)
                        assert_equal(drops[][5], 4)
                        assert_equal(drops[][4], 2 if raising and active and mode == 2 else 0)
                        assert_equal(len(trace[]), 2 if active else 0)
                        if active:
                            assert_equal(trace[][1] - trace[][0], 101)
                        var total = 0
                        for i in range(5): total += drops[][i]
                        assert_equal(total, 4 if active else 2)
                        traces.append(trace[].copy())
                        drop_counts.append(drops[].copy())
                    assert_equal(outputs[0], outputs[1])
                    assert_equal(traces[0], traces[1])
                    assert_equal(drop_counts[0], drop_counts[1])
