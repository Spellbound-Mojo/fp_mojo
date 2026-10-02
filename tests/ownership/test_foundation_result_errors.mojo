"""Native-reference transformation, elimination, closure and failure lifetimes."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.utils import Variant
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct FoundationResultErrorsToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct FoundationResultErrorsFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def read(value: FoundationResultErrorsToken) -> Int:
    return value.value

def error_code(error: FoundationResultErrorsToken) -> Int:
    return -error.value

def transform(library: Bool, operation: Int, ok: Bool, mode: Int,
              drops: ArcPointer[Int], errors: ArcPointer[Int], states: ArcPointer[Int],
              trace: ArcPointer[List[Int]]) -> Int:
    var state0 = FoundationResultErrorsToken(10, states)
    def mapper(var value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state0^, mode, errors, trace} -> FoundationResultErrorsToken:
        state0.value += 1
        trace[].append(state0.value + value.value)
        if mode == 2:
            raise FoundationResultErrorsFailure(value.value + 100, errors)
        value.value += state0.value
        return value^
    var state1 = FoundationResultErrorsToken(20, states)
    def bind(var value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state1^, mode, errors, trace} -> Result[FoundationResultErrorsToken, FoundationResultErrorsToken]:
        state1.value += 1
        trace[].append(state1.value + value.value)
        if mode == 2:
            raise FoundationResultErrorsFailure(value.value + 200, errors)
        value.value += state1.value
        if mode == 1:
            return Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Err(value^))
        return Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Ok(value^))
    var native = Variant[Ok[FoundationResultErrorsToken], Err[FoundationResultErrorsToken]](Ok(FoundationResultErrorsToken(7, drops))) if ok else Variant[Ok[FoundationResultErrorsToken], Err[FoundationResultErrorsToken]](Err(FoundationResultErrorsToken(7, drops)))
    try:
        var output: Result[FoundationResultErrorsToken, FoundationResultErrorsToken]
        if library:
            var value = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](native^.unwrap[Ok[FoundationResultErrorsToken]]()) if ok else Result[FoundationResultErrorsToken, FoundationResultErrorsToken](native^.unwrap[Err[FoundationResultErrorsToken]]())
            if operation == 0:
                output = map[ResultFamily[type_of(value).Error]](mapper, value^)
            elif operation == 1:
                output = flat_map[ResultFamily[type_of(value).Error]](bind, value^)
            elif operation == 2:
                output = value^.map_err(mapper)
            else:
                output = value^.or_else(bind)
        elif native.isa[Ok[FoundationResultErrorsToken]]():
            var value = native^.unwrap[Ok[FoundationResultErrorsToken]]().into_payload()
            if operation == 0:
                output = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Ok(mapper(value^)))
            elif operation == 1:
                output = bind(value^)
            else:
                output = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Ok(value^))
        else:
            var error = native^.unwrap[Err[FoundationResultErrorsToken]]().into_payload()
            if operation == 2:
                output = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Err(mapper(error^)))
            elif operation == 3:
                output = bind(error^)
            else:
                output = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](Err(error^))
        return output.fold(read, error_code)
    except error:
        comptime assert type_of(error) == FoundationResultErrorsFailure
        return -1000 - error.code

def eliminate(library: Bool, owned: Bool, ok: Bool, combination: Int, fail: Bool,
              drops: ArcPointer[Int], errors: ArcPointer[Int], states: ArcPointer[Int],
              trace: ArcPointer[List[Int]]) -> Int:
    var state2 = FoundationResultErrorsToken(10, states)
    def borrow_ok(value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state2^, fail, errors, drops, trace} -> FoundationResultErrorsToken:
        state2.value += 1
        trace[].append(state2.value + value.value)
        if fail: raise FoundationResultErrorsFailure(111, errors)
        return FoundationResultErrorsToken(state2.value + value.value, drops)
    var state3 = FoundationResultErrorsToken(20, states)
    def borrow_err(value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state3^, fail, errors, drops, trace} -> FoundationResultErrorsToken:
        state3.value += 1
        trace[].append(state3.value + value.value)
        if fail: raise FoundationResultErrorsFailure(222, errors)
        return FoundationResultErrorsToken(state3.value + value.value, drops)
    var state4 = FoundationResultErrorsToken(30, states)
    def own_ok(var value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state4^, fail, errors, trace} -> FoundationResultErrorsToken:
        state4.value += 1
        trace[].append(state4.value + value.value)
        if fail: raise FoundationResultErrorsFailure(333, errors)
        value.value += state4.value
        return value^
    var state5 = FoundationResultErrorsToken(40, states)
    def own_err(var value: FoundationResultErrorsToken) raises FoundationResultErrorsFailure {var state5^, fail, errors, trace} -> FoundationResultErrorsToken:
        state5.value += 1
        trace[].append(state5.value + value.value)
        if fail: raise FoundationResultErrorsFailure(444, errors)
        value.value += state5.value
        return value^
    def pure_borrow(value: FoundationResultErrorsToken) {drops, trace} -> FoundationResultErrorsToken:
        trace[].append(50 + value.value)
        return FoundationResultErrorsToken(50 + value.value, drops)
    def pure_owned(var value: FoundationResultErrorsToken) {trace} -> FoundationResultErrorsToken:
        trace[].append(60 + value.value)
        value.value += 60
        return value^
    var native = Variant[Ok[FoundationResultErrorsToken], Err[FoundationResultErrorsToken]](Ok(FoundationResultErrorsToken(7, drops))) if ok else Variant[Ok[FoundationResultErrorsToken], Err[FoundationResultErrorsToken]](Err(FoundationResultErrorsToken(7, drops)))
    try:
        var output: FoundationResultErrorsToken
        if library:
            var value = Result[FoundationResultErrorsToken, FoundationResultErrorsToken](native^.unwrap[Ok[FoundationResultErrorsToken]]()) if ok else Result[FoundationResultErrorsToken, FoundationResultErrorsToken](native^.unwrap[Err[FoundationResultErrorsToken]]())
            if owned:
                if combination == 0: output = value^.fold_owned(own_ok, pure_owned)
                elif combination == 1: output = value^.fold_owned(pure_owned, own_err)
                else: output = value^.fold_owned(own_ok, own_err)
            else:
                if combination == 0: output = value.fold(borrow_ok, pure_borrow)
                elif combination == 1: output = value.fold(pure_borrow, borrow_err)
                else: output = value.fold(borrow_ok, borrow_err)
                # A second use verifies that borrowed elimination preserves the subject.
                trace[].append(value.fold(read, error_code))
        elif ok:
            if owned:
                var payload = native^.unwrap[Ok[FoundationResultErrorsToken]]().into_payload()
                output = pure_owned(payload^) if combination == 1 else own_ok(payload^)
            else:
                ref payload = native.unsafe_get[Ok[FoundationResultErrorsToken]]().value
                output = pure_borrow(payload) if combination == 1 else borrow_ok(payload)
                trace[].append(payload.value)
        else:
            if owned:
                var payload = native^.unwrap[Err[FoundationResultErrorsToken]]().into_payload()
                output = pure_owned(payload^) if combination == 0 else own_err(payload^)
            else:
                ref payload = native.unsafe_get[Err[FoundationResultErrorsToken]]().value
                output = pure_borrow(payload) if combination == 0 else borrow_err(payload)
                trace[].append(-payload.value)
        return output.value
    except error:
        comptime assert type_of(error) == FoundationResultErrorsFailure
        return -1000 - error.code

def main() raises:
    for operation in range(4):
        for ok in range(2):
            for mode in range(3):
                var observed = List[Int]()
                var traces = List[List[Int]]()
                for library in range(2):
                    var drops = ArcPointer(0)
                    var errors = ArcPointer(0)
                    var states = ArcPointer(0)
                    var trace = ArcPointer(List[Int]())
                    observed.append(transform(Bool(library), operation, Bool(ok), mode, drops, errors, states, trace))
                    assert_equal(drops[], 1)
                    assert_equal(states[], 2)
                    var active = Bool(ok) == (operation < 2)
                    assert_equal(errors[], 1 if active and mode == 2 else 0)
                    assert_equal(len(trace[]), 1 if active else 0)
                    traces.append(trace[].copy())
                assert_equal(observed[0], observed[1])
                assert_equal(traces[0], traces[1])
    for owned in range(2):
        for ok in range(2):
            for combination in range(3):
                for fail in range(2):
                    var observed = List[Int]()
                    var traces = List[List[Int]]()
                    for library in range(2):
                        var drops = ArcPointer(0)
                        var errors = ArcPointer(0)
                        var states = ArcPointer(0)
                        var trace = ArcPointer(List[Int]())
                        observed.append(eliminate(Bool(library), Bool(owned), Bool(ok), combination, Bool(fail), drops, errors, states, trace))
                        var raising = combination == 2 or combination == (0 if ok else 1)
                        var failed = raising and Bool(fail)
                        assert_equal(errors[], 1 if failed else 0)
                        assert_equal(states[], 4)
                        assert_equal(drops[], 1 if owned or failed else 2)
                        assert_equal(len(trace[]), 1 if owned or failed else 2)
                        traces.append(trace[].copy())
                    assert_equal(observed[0], observed[1])
                    assert_equal(traces[0], traces[1])
