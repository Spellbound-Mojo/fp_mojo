"""A mapping-only base Monad delegates execution without supplying recovery."""
from fp.algebra import Monad, ErrorMapping, ResultFamily, ValidationFamily, StringMonoid
from fp.callables import UnaryContract, BinaryContract, ThunkContract

struct ToValidation(Monad,ErrorMapping):
    comptime Base = ResultFamily[String]
    comptime Failure = String
    comptime Element[V:Movable & Deinitable] = Self.Base.Element[V]
    comptime CarrierCompatible[V:Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    comptime ErrorCarrierCompatible[V:Movable & Deinitable] = Self.Base.ErrorCarrierCompatible[V]
    comptime DefaultErrorTarget[A:Movable & Deinitable,G:Movable & Deinitable] = ValidationFamily[StringMonoid]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Pure[A:Movable & Deinitable] = Self.Base.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Bound[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = Self.Base.BindError[V,F]
    comptime BimapCompatible[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable] = ((Target == ValidationFamily[StringMonoid]) | (Target == ResultFamily[String])) and Self.Base.BimapCompatible[ResultFamily[G.Out],V,F,G]
    comptime Bimapped[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable] = Self.Base.Bimapped[ResultFamily[G.Out],V,F,G]
    comptime BimapError[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable] = Self.Base.BimapError[ResultFamily[G.Out],V,F,G]
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A)->Self.Pure[A]:return Self.Base.pure(value^)
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var source:V) raises Self.MapError[V,F] ->Self.Mapped[V,F]:return Self.Base.map(f^,source^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R] ->Self.Combined[V,F,R]:return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def flat_map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var source:V) raises Self.BindError[V,F] ->Self.Bound[V,F]:return Self.Base.flat_map(f^,source^)
    @staticmethod
    def bimap[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable](var f:F,var g:G,var source:V) raises Self.BimapError[Target,V,F,G] ->Self.Bimapped[Target,V,F,G]:return Self.Base.bimap[ResultFamily[G.Out]](f^,g^,source^)
