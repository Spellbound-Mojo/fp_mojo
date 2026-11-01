"""Family primitives delegate; admission remains a selected-entry obligation."""
from fp.algebra import ApplicativeError, Monad, ResultFamily
from fp.callables import UnaryContract, BinaryContract, ThunkContract

struct Restricted[map_input: Bool, map_outcome: Bool, bind_outcome: Bool, handle: Bool](ApplicativeError, Monad):
    comptime Base = ResultFamily[String]
    # The original source contains Int; materialization exposes Result[Int,String].
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.map_input if F.Arg == Int else Self.map_outcome
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.bind_outcome
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.BindError[V,F]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.HandleError[V,H]
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.handle and Self.Base._Handles[V,H]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(function^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var function: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(function^,left^,right^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.BindError[V,F] -> Self.Bound[V,F]: return Self.Base.flat_map(function^,value^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) -> Self.Failed[A]: return Self.Base.fail[A](error^)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V,H] -> Self.Handled[V,H]: return Self.Base.or_else(handler^,source^)
