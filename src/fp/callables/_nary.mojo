"""Generated native tuple application boundaries; do not edit by hand.

Mojo distinguishes a fixed native signature from a variadic pack signature.
Each arity adapts that native call to Unary over a tuple; family execution stays
in algebra._nary. Native Tuple.consume_elements moves the inputs into untagged
slots; every slot is consumed before the possibly raising native call.
"""
from std.builtin.rebind import downcast, rebind_var
from std.memory import MaybeUninit
from .protocols import Unary
from .products import _take_pair, _OptionalCell
from .native import _NativeOwnedArg, _call_native, _call_native_binary, _Unary, _RaisingUnary, _Binary, _RaisingBinary

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

struct _OwnedNativeNary1[A0: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary1[Self.A0, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

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

struct _OwnedNativeNary2[A0: Movable & Deinitable, A1: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary2[Self.A0, Self.A1, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2) -> R
comptime _RaisingNary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^)

struct _OwnedNativeNary3[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary3[Self.A0, Self.A1, Self.A2, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3) -> R
comptime _RaisingNary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^)

struct _OwnedNativeNary4[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary4[Self.A0, Self.A1, Self.A2, Self.A3, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4) -> R
comptime _RaisingNary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^)

struct _OwnedNativeNary5[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary5[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5) -> R
comptime _RaisingNary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^)

struct _OwnedNativeNary6[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary6[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6) -> R
comptime _RaisingNary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^)

struct _OwnedNativeNary7[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary7[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)

comptime _Nary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6, var A7) -> R
comptime _RaisingNary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A0, var A1, var A2, var A3, var A4, var A5, var A6, var A7) raises X -> R

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
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^)))
            elif Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin -> Out:
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^)))
            elif not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin -> Out:
                comptime assert Self.X == Never
                return rebind_var[Self.R](rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin -> Out](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin:
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin:
            comptime assert Self.X == Never
            _ = rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.X == Never and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Never thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
        comptime if Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin -> Self.R:
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) raises Self.X thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
        comptime if not Self.raising and Self.F == def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin -> Self.R:
            comptime assert Self.X == Never
            return rebind[def(var _NativeOwnedArg[Self.A0], var _NativeOwnedArg[Self.A1], var _NativeOwnedArg[Self.A2], var _NativeOwnedArg[Self.A3], var _NativeOwnedArg[Self.A4], var _NativeOwnedArg[Self.A5], var _NativeOwnedArg[Self.A6], var _NativeOwnedArg[Self.A7]) thin -> Self.R](self.function[])(rebind_var[_NativeOwnedArg[Self.A0]](a0^), rebind_var[_NativeOwnedArg[Self.A1]](a1^), rebind_var[_NativeOwnedArg[Self.A2]](a2^), rebind_var[_NativeOwnedArg[Self.A3]](a3^), rebind_var[_NativeOwnedArg[Self.A4]](a4^), rebind_var[_NativeOwnedArg[Self.A5]](a5^), rebind_var[_NativeOwnedArg[Self.A6]](a6^), rebind_var[_NativeOwnedArg[Self.A7]](a7^))
        comptime if Self.R == type_of(None) and Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7) raises Never]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7) raises Self.X]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7)]
            _ = rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.X == Never:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7) raises Never -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7) raises Self.X -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)
        elif True:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, def(var Self.A0, var Self.A1, var Self.A2, var Self.A3, var Self.A4, var Self.A5, var Self.A6, var Self.A7) -> Self.R]
            return rebind[Fn](self.function[])(a0^, a1^, a2^, a3^, a4^, a5^, a6^, a7^)

struct _OwnedNativeNary8[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Unary, Copyable where conforms_to(F, Copyable)):
    # Deferred families retain the pointer value, never a borrow of its local
    # variable. The existing adapter still owns tuple extraction and invocation.
    comptime Arg = Tuple[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7]
    comptime Out = Self.R
    comptime Error = Self.X
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self, var arg: Self.Arg) raises Self.X -> Self.R:
        ref function = self._function.value()
        return _NativeNary8[Self.A0, Self.A1, Self.A2, Self.A3, Self.A4, Self.A5, Self.A6, Self.A7, Self.R, Self.X, Self.F, Self.raising, origin_of(function)](Pointer(to=function)).call(arg^)
