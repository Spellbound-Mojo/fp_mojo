"""Expose a Monad through the public protocols, with operation fault injection."""
from fp.algebra import Monad
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from std.builtin.rebind import rebind_var
from std.os import abort


def _forward[E: Movable & Deinitable, A: Movable & Deinitable](var error: A) raises E -> Never:
    comptime if A == Never:
        abort("external: unreachable error")
    else:
        comptime assert A == E, "external: delegated error type changed"
        raise rebind_var[E](error^)


struct PublicMonad[M: Monad, fail_stage: Int = -1](Monad):
    """Delegate to M; stage 1 fails map, 2 flat_map and 3 map2_lazy with Int(701 + stage)."""
    comptime Element[V: Movable & Deinitable] = Self.M.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int if Self.fail_stage == 1 else Self.M.MapError[V, F]
    comptime Pure[A: Movable & Deinitable] = Self.M.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.M.Combined[V, F, R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Int if Self.fail_stage == 3 else Self.M.CombineError[V, F, R]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Bound[V, F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int if Self.fail_stage == 2 else Self.M.BindError[V, F]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime if Self.fail_stage == 1:
            raise rebind_var[Self.MapError[V, F]](Int(702))
        try:
            return Self.M.map(f^, value^)
        except error:
            _forward[Self.MapError[V, F]](error^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return Self.M.pure(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        comptime if Self.fail_stage == 3:
            raise rebind_var[Self.CombineError[V, F, R]](Int(704))
        try:
            return Self.M.map2_lazy(f^, left^, right^)
        except error:
            _forward[Self.CombineError[V, F, R]](error^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        comptime if Self.fail_stage == 2:
            raise rebind_var[Self.BindError[V, F]](Int(703))
        try:
            return Self.M.flat_map(f^, value^)
        except error:
            _forward[Self.BindError[V, F]](error^)
