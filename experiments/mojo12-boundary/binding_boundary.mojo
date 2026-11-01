"""Unqualified Capture argument-binding experiment; see the architecture docs.

Factories select error and argument convention before accepting a callback.
The wrappers only delegate to existing native adapters and Result capture.
Known failing clients remain failures in bindings.json.
"""
from fp.callables.native import (
    _NativeUnaryRef, _NativeMutatingRef, _NativeMutOwnedRef,
    _NativeMutOwnedKeywordsRef,
)
from fp.data._result import (
    Result, attempt as _capture_arguments, attempt_kwargs as _capture_keywords,
)

@fieldwise_init
struct _CaptureMutating[A: Movable & Deinitable, R: Movable & Deinitable,
                       E: Movable & Deinitable, F: Movable & Deinitable,
                       raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var callback: _NativeMutatingRef[Self.A, Self.R, Self.E, Self.F, Self.raising, Self.o]

    def run(self, mut value: Self.A) -> Result[Self.R, Self.E]:
        return _capture_arguments(self.callback, value)


@fieldwise_init
struct _CaptureConsuming[A: Movable & Deinitable, R: Movable & Deinitable,
                        E: Movable & Deinitable, F: Movable & Deinitable,
                        raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var callback: _NativeUnaryRef[Self.A, Self.R, Self.E, Self.F, Self.raising, Self.o]

    def run(self, var value: Self.A) -> Result[Self.R, Self.E]:
        return _capture_arguments(self.callback, value^)


@fieldwise_init
struct _CaptureMutOwned[A: Movable & Deinitable, B: Movable & Deinitable,
                       R: Movable & Deinitable, E: Movable & Deinitable,
                       F: Movable & Deinitable, raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var callback: _NativeMutOwnedRef[Self.A, Self.B, Self.R, Self.E, Self.F, Self.raising, Self.o]

    def run(self, mut first: Self.A, var second: Self.B) -> Result[Self.R, Self.E]:
        return _capture_arguments(self.callback, first, second^)


@fieldwise_init
struct _CaptureMutOwnedKeywords[A: Movable & Deinitable, B: Movable & Deinitable,
                               K: Movable & Deinitable, R: Movable & Deinitable,
                               E: Movable & Deinitable, F: Movable & Deinitable,
                               raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var callback: _NativeMutOwnedKeywordsRef[Self.A, Self.B, Self.K, Self.R, Self.E, Self.F, Self.raising, Self.o]

    def run(self, mut first: Self.A, var second: Self.B, /, var **values: Self.K) -> Result[Self.R, Self.E]:
        return _capture_keywords(self.callback, first, second^, **values^)


struct Capture[E: Movable & Deinitable]:
    @staticmethod
    def mutating[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A) -> R](ref[o] function: F) -> _CaptureMutating[A, R, Never, F, False, o]:
        return _CaptureMutating[A, R, Never, F, False, o](_NativeMutatingRef[A, R, Never, F, False, o](Pointer(to=function)))

    @staticmethod
    def mutating[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A) raises Self.E -> R](ref[o] function: F) -> _CaptureMutating[A, R, Self.E, F, True, o]:
        return _CaptureMutating[A, R, Self.E, F, True, o](_NativeMutatingRef[A, R, Self.E, F, True, o](Pointer(to=function)))

    @staticmethod
    def consuming[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(var A) -> R](ref[o] function: F) -> _CaptureConsuming[A, R, Never, F, False, o]:
        return _CaptureConsuming[A, R, Never, F, False, o](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)))

    @staticmethod
    def consuming[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(var A) raises Self.E -> R](ref[o] function: F) -> _CaptureConsuming[A, R, Self.E, F, True, o]:
        return _CaptureConsuming[A, R, Self.E, F, True, o](_NativeUnaryRef[A, R, Self.E, F, True, o](Pointer(to=function)))

    @staticmethod
    def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A, var B) -> R](ref[o] function: F) -> _CaptureMutOwned[A, B, R, Never, F, False, o]:
        return _CaptureMutOwned[A, B, R, Never, F, False, o](_NativeMutOwnedRef[A, B, R, Never, F, False, o](Pointer(to=function)))

    @staticmethod
    def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A, var B) raises Self.E -> R](ref[o] function: F) -> _CaptureMutOwned[A, B, R, Self.E, F, True, o]:
        return _CaptureMutOwned[A, B, R, Self.E, F, True, o](_NativeMutOwnedRef[A, B, R, Self.E, F, True, o](Pointer(to=function)))

    @staticmethod
    def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A, var B, /, var **kwargs: K) -> R](ref[o] function: F) -> _CaptureMutOwnedKeywords[A, B, K, R, Never, F, False, o]:
        return _CaptureMutOwnedKeywords[A, B, K, R, Never, F, False, o](_NativeMutOwnedKeywordsRef[A, B, K, R, Never, F, False, o](Pointer(to=function)))

    @staticmethod
    def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 F: def(mut A, var B, /, var **kwargs: K) raises Self.E -> R](ref[o] function: F) -> _CaptureMutOwnedKeywords[A, B, K, R, Self.E, F, True, o]:
        return _CaptureMutOwnedKeywords[A, B, K, R, Self.E, F, True, o](_NativeMutOwnedKeywordsRef[A, B, K, R, Self.E, F, True, o](Pointer(to=function)))
