from fp.callables.native import _NativeMutOwnedKeywordsRef
from fp._binding_architecture import _CaptureMutOwnedKeywords
from fp.data._result import Result, attempt_kwargs as _capture_keywords

@fieldwise_init
struct _ThinKeywords[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
                     R: Movable & Deinitable, F: Movable & Deinitable](Movable):
    var function: Self.F
    def run(self, mut first: Self.A, var second: Self.B, /, var **values: Self.K) -> Result[Self.R, Never]:
        comptime o = origin_of(self.function)
        var callback = _NativeMutOwnedKeywordsRef[Self.A, Self.B, Self.K, Self.R, Never, Self.F, True, o](Pointer(to=self.function))
        return _capture_keywords(callback, first, second^, **values^)

struct KeywordCall[A: Movable & Deinitable, B: Movable & Deinitable,
                   K: Movable & Deinitable, E: Movable & Deinitable]:
    @staticmethod
    def of[R: Movable & Deinitable, o: ImmOrigin, //,
           F: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) -> R](ref[o] function: F) -> _CaptureMutOwnedKeywords[Self.A, Self.B, Self.K, R, Never, F, False, o]:
        return _CaptureMutOwnedKeywords[Self.A, Self.B, Self.K, R, Never, F, False, o](_NativeMutOwnedKeywordsRef[Self.A, Self.B, Self.K, R, Never, F, False, o](Pointer(to=function)))
    @staticmethod
    def of[R: Movable & Deinitable, o: ImmOrigin, //,
           F: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E -> R](ref[o] function: F) -> _CaptureMutOwnedKeywords[Self.A, Self.B, Self.K, R, Self.E, F, True, o]:
        return _CaptureMutOwnedKeywords[Self.A, Self.B, Self.K, R, Self.E, F, True, o](_NativeMutOwnedKeywordsRef[Self.A, Self.B, Self.K, R, Self.E, F, True, o](Pointer(to=function)))

    @staticmethod
    def of(function: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin) -> _ThinKeywords[Self.A, Self.B, Self.K, type_of(None), type_of(function)]:
        return _ThinKeywords[Self.A, Self.B, Self.K, type_of(None), type_of(function)](function)

    @staticmethod
    def of[R: Movable & Deinitable, //](function: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> R) -> _ThinKeywords[Self.A, Self.B, Self.K, R, type_of(function)]:
        return _ThinKeywords[Self.A, Self.B, Self.K, R, type_of(function)](function)
