"""Generated native tuple application boundaries; do not edit by hand.

Mojo distinguishes a fixed native signature from a variadic pack signature.
Each arity adapts that native call to Unary over a tuple; family execution stays
in algebra._nary. Native Tuple.consume_elements moves the inputs into untagged
slots; every slot is consumed before the possibly raising native call.
"""
from std.builtin.rebind import downcast, rebind_var
from std.memory import MaybeUninit
from .protocols import Unary
from .products import _take_pair
from .native import _call_native, _call_native_binary, _Unary, _RaisingUnary, _Binary, _RaisingBinary

comptime _Nary1[A0: Movable & Deinitable, R: Movable & Deinitable] = _Unary[A0, R]
comptime _RaisingNary1[A0: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = _RaisingUnary[A0, R, X]

@fieldwise_init
struct _NativeNary1[A0: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0}:
            slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        return _call_native[Self.A0, Self.R, Self.X, Self.F, Self.raising](self.function[], a0^)

comptime _Nary2[A0: Movable & Deinitable, A1: Movable & Deinitable, R: Movable & Deinitable] = _Binary[A0, A1, R]
comptime _RaisingNary2[A0: Movable & Deinitable, A1: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = _RaisingBinary[A0, A1, R, X]

@fieldwise_init
struct _NativeNary2[A0: Movable & Deinitable, A1: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        _take_pair(arg^, slot0, slot1)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        return _call_native_binary[Self.A0, Self.A1, Self.R, Self.X, Self.F, Self.raising](self.function[], a0^, a1^)

comptime _Nary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2) -> R
comptime _RaisingNary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2) raises X -> R

def _native_nary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, F: _Nary3[A0, A1, A2, R]](function: F, var a0: A0, var a1: A1, var a2: A2) -> R:
    return function(a0^, a1^, a2^)

def _native_nary3_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary3[A0, A1, A2, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2) raises X -> R:
    return function(a0^, a1^, a2^)

@fieldwise_init
struct _NativeNary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            else:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary3[Self.A0, Self.A1, Self.A2, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary3[Self.A0, Self.A1, Self.A2, Self.R, Self.X])
            return _native_nary3_raising[Self.A0, Self.A1, Self.A2, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^)
        else:
            comptime Fn = downcast[Self.F, _Nary3[Self.A0, Self.A1, Self.A2, Self.R]]
            comptime assert conforms_to(Fn, _Nary3[Self.A0, Self.A1, Self.A2, Self.R]) and Self.X == Never
            return _native_nary3[Self.A0, Self.A1, Self.A2, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^)

comptime _Nary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3) -> R
comptime _RaisingNary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3) raises X -> R

def _native_nary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, F: _Nary4[A0, A1, A2, A3, R]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3) -> R:
    return function(a0^, a1^, a2^, a3^)

def _native_nary4_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary4[A0, A1, A2, A3, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3) raises X -> R:
    return function(a0^, a1^, a2^, a3^)

@fieldwise_init
struct _NativeNary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        var slot3 = MaybeUninit[Self.A3]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2, ref slot3}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            elif index == 2:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
            else:
                slot3.unsafe_ptr().unsafe_write(rebind_var[Self.A3](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        var a3 = slot3^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R, Self.X])
            return _native_nary4_raising[Self.A0, Self.A1, Self.A2, Self.A3, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^)
        else:
            comptime Fn = downcast[Self.F, _Nary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R]]
            comptime assert conforms_to(Fn, _Nary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R]) and Self.X == Never
            return _native_nary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^)

comptime _Nary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4) -> R
comptime _RaisingNary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4) raises X -> R

def _native_nary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, F: _Nary5[A0, A1, A2, A3, A4, R]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4) -> R:
    return function(a0^, a1^, a2^, a3^, a4^)

def _native_nary5_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary5[A0, A1, A2, A3, A4, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4) raises X -> R:
    return function(a0^, a1^, a2^, a3^, a4^)

@fieldwise_init
struct _NativeNary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        var slot3 = MaybeUninit[Self.A3]()
        var slot4 = MaybeUninit[Self.A4]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2, ref slot3, ref slot4}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            elif index == 2:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
            elif index == 3:
                slot3.unsafe_ptr().unsafe_write(rebind_var[Self.A3](value^))
            else:
                slot4.unsafe_ptr().unsafe_write(rebind_var[Self.A4](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        var a3 = slot3^.unsafe_assume_init()
        var a4 = slot4^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R, Self.X])
            return _native_nary5_raising[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^)
        else:
            comptime Fn = downcast[Self.F, _Nary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R]]
            comptime assert conforms_to(Fn, _Nary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R]) and Self.X == Never
            return _native_nary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^)

comptime _Nary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5) -> R
comptime _RaisingNary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5) raises X -> R

def _native_nary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, F: _Nary6[A0, A1, A2, A3, A4, A5, R]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5) -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^)

def _native_nary6_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary6[A0, A1, A2, A3, A4, A5, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5) raises X -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^)

@fieldwise_init
struct _NativeNary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        var slot3 = MaybeUninit[Self.A3]()
        var slot4 = MaybeUninit[Self.A4]()
        var slot5 = MaybeUninit[Self.A5]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2, ref slot3, ref slot4, ref slot5}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            elif index == 2:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
            elif index == 3:
                slot3.unsafe_ptr().unsafe_write(rebind_var[Self.A3](value^))
            elif index == 4:
                slot4.unsafe_ptr().unsafe_write(rebind_var[Self.A4](value^))
            else:
                slot5.unsafe_ptr().unsafe_write(rebind_var[Self.A5](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        var a3 = slot3^.unsafe_assume_init()
        var a4 = slot4^.unsafe_assume_init()
        var a5 = slot5^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R, Self.X])
            return _native_nary6_raising[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^)
        else:
            comptime Fn = downcast[Self.F, _Nary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R]]
            comptime assert conforms_to(Fn, _Nary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R]) and Self.X == Never
            return _native_nary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^)

comptime _Nary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6) -> R
comptime _RaisingNary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6) raises X -> R

def _native_nary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, F: _Nary7[A0, A1, A2, A3, A4, A5, A6, R]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6) -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^, a6^)

def _native_nary7_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary7[A0, A1, A2, A3, A4, A5, A6, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6) raises X -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^, a6^)

@fieldwise_init
struct _NativeNary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        var slot3 = MaybeUninit[Self.A3]()
        var slot4 = MaybeUninit[Self.A4]()
        var slot5 = MaybeUninit[Self.A5]()
        var slot6 = MaybeUninit[Self.A6]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2, ref slot3, ref slot4, ref slot5, ref slot6}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            elif index == 2:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
            elif index == 3:
                slot3.unsafe_ptr().unsafe_write(rebind_var[Self.A3](value^))
            elif index == 4:
                slot4.unsafe_ptr().unsafe_write(rebind_var[Self.A4](value^))
            elif index == 5:
                slot5.unsafe_ptr().unsafe_write(rebind_var[Self.A5](value^))
            else:
                slot6.unsafe_ptr().unsafe_write(rebind_var[Self.A6](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        var a3 = slot3^.unsafe_assume_init()
        var a4 = slot4^.unsafe_assume_init()
        var a5 = slot5^.unsafe_assume_init()
        var a6 = slot6^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R, Self.X])
            return _native_nary7_raising[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^, a6^)
        else:
            comptime Fn = downcast[Self.F, _Nary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R]]
            comptime assert conforms_to(Fn, _Nary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R]) and Self.X == Never
            return _native_nary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^, a6^)

comptime _Nary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6, var A7) -> R
comptime _RaisingNary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6, var A7) raises X -> R

def _native_nary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, F: _Nary8[A0, A1, A2, A3, A4, A5, A6, A7, R]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6, var a7: A7) -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)

def _native_nary8_raising[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X]](function: F, var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6, var a7: A7) raises X -> R:
    return function(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)

@fieldwise_init
struct _NativeNary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Unary, ImplicitlyCopyable):
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7]
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        var slot0 = MaybeUninit[Self.A0]()
        var slot1 = MaybeUninit[Self.A1]()
        var slot2 = MaybeUninit[Self.A2]()
        var slot3 = MaybeUninit[Self.A3]()
        var slot4 = MaybeUninit[Self.A4]()
        var slot5 = MaybeUninit[Self.A5]()
        var slot6 = MaybeUninit[Self.A6]()
        var slot7 = MaybeUninit[Self.A7]()
        def store[index: Int](var value: Self.Arg.Ts[index]) {ref slot0, ref slot1, ref slot2, ref slot3, ref slot4, ref slot5, ref slot6, ref slot7}:
            comptime if index == 0:
                slot0.unsafe_ptr().unsafe_write(rebind_var[Self.A0](value^))
            elif index == 1:
                slot1.unsafe_ptr().unsafe_write(rebind_var[Self.A1](value^))
            elif index == 2:
                slot2.unsafe_ptr().unsafe_write(rebind_var[Self.A2](value^))
            elif index == 3:
                slot3.unsafe_ptr().unsafe_write(rebind_var[Self.A3](value^))
            elif index == 4:
                slot4.unsafe_ptr().unsafe_write(rebind_var[Self.A4](value^))
            elif index == 5:
                slot5.unsafe_ptr().unsafe_write(rebind_var[Self.A5](value^))
            elif index == 6:
                slot6.unsafe_ptr().unsafe_write(rebind_var[Self.A6](value^))
            else:
                slot7.unsafe_ptr().unsafe_write(rebind_var[Self.A7](value^))
        arg^.consume_elements(store)
        var a0 = slot0^.unsafe_assume_init()
        var a1 = slot1^.unsafe_assume_init()
        var a2 = slot2^.unsafe_assume_init()
        var a3 = slot3^.unsafe_assume_init()
        var a4 = slot4^.unsafe_assume_init()
        var a5 = slot5^.unsafe_assume_init()
        var a6 = slot6^.unsafe_assume_init()
        var a7 = slot7^.unsafe_assume_init()
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingNary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R, Self.X]]
            comptime assert conforms_to(Fn, _RaisingNary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R, Self.X])
            return _native_nary8_raising[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R, Self.X, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
        else:
            comptime Fn = downcast[Self.F, _Nary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R]]
            comptime assert conforms_to(Fn, _Nary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R]) and Self.X == Never
            return _native_nary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R, Fn](rebind[Fn](self.function[]), a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
