"""Owned callback storage experiment."""
from fp.callables.native import _NativeUnaryRef, _NativeMutatingRef, _NativeMutOwnedRef, _NativeMutOwnedKeywordsRef
from fp.callables.products import _OptionalCell
from fp.data._result import Result, attempt as _capture_arguments, attempt_kwargs as _capture_keywords

struct OwnedMutating[A: Movable & Deinitable, R: Movable & Deinitable,
                      E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Movable):
    var function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self.function = Optional(function^)
    def run(mut self, mut value: Self.A) -> Result[Self.R, Self.E]:
        comptime o = origin_of(self.function._value)
        var callback = _NativeMutatingRef[Self.A, Self.R, Self.E, Self.F, Self.raising, o](Pointer(to=self.function.value()))
        return _capture_arguments(callback, value)

struct OwnedConsuming[A: Movable & Deinitable, R: Movable & Deinitable,
                      E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Movable):
    var function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self.function = Optional(function^)
    def run(mut self, var value: Self.A) -> Result[Self.R, Self.E]:
        comptime o = origin_of(self.function._value)
        var callback = _NativeUnaryRef[Self.A, Self.R, Self.E, Self.F, Self.raising, o](Pointer(to=self.function.value()))
        return _capture_arguments(callback, value^)

struct OwnedMutOwned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                      E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Movable):
    var function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self.function = Optional(function^)
    def run(mut self, mut first: Self.A, var second: Self.B) -> Result[Self.R, Self.E]:
        comptime o = origin_of(self.function._value)
        var callback = _NativeMutOwnedRef[Self.A, Self.B, Self.R, Self.E, Self.F, Self.raising, o](Pointer(to=self.function.value()))
        return _capture_arguments(callback, first, second^)

struct OwnedKeywords[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable,
                      E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](Movable):
    var function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self.function = Optional(function^)
    def run(mut self, mut first: Self.A, var second: Self.B, /, var **values: Self.K) -> Result[Self.R, Self.E]:
        comptime o = origin_of(self.function._value)
        var callback = _NativeMutOwnedKeywordsRef[Self.A, Self.B, Self.K, Self.R, Self.E, Self.F, Self.raising, o](Pointer(to=self.function.value()))
        return _capture_keywords(callback, first, second^, **values^)

struct Capture[E: Movable & Deinitable]:
    @staticmethod
    def mutating[A: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A) -> R](var function: F) -> OwnedMutating[A, R, Never, F, False]:
        return OwnedMutating[A, R, Never, F, False](function^)
    @staticmethod
    def mutating[A: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A) raises Self.E -> R](var function: F) -> OwnedMutating[A, R, Self.E, F, True]:
        return OwnedMutating[A, R, Self.E, F, True](function^)
    @staticmethod
    def consuming[A: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(var A) -> R](var function: F) -> OwnedConsuming[A, R, Never, F, False]:
        return OwnedConsuming[A, R, Never, F, False](function^)
    @staticmethod
    def consuming[A: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(var A) raises Self.E -> R](var function: F) -> OwnedConsuming[A, R, Self.E, F, True]:
        return OwnedConsuming[A, R, Self.E, F, True](function^)
    @staticmethod
    def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A, var B) -> R](var function: F) -> OwnedMutOwned[A, B, R, Never, F, False]:
        return OwnedMutOwned[A, B, R, Never, F, False](function^)
    @staticmethod
    def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A, var B) raises Self.E -> R](var function: F) -> OwnedMutOwned[A, B, R, Self.E, F, True]:
        return OwnedMutOwned[A, B, R, Self.E, F, True](function^)
    @staticmethod
    def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A, var B, /, var **kwargs: K) -> R](var function: F) -> OwnedKeywords[A, B, K, R, Never, F, False]:
        return OwnedKeywords[A, B, K, R, Never, F, False](function^)
    @staticmethod
    def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //,
                F: def(mut A, var B, /, var **kwargs: K) raises Self.E -> R](var function: F) -> OwnedKeywords[A, B, K, R, Self.E, F, True]:
        return OwnedKeywords[A, B, K, R, Self.E, F, True](function^)
