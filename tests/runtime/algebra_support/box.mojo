"""An independent third-party family implemented through the public protocols."""
from fp.algebra import Functor, Applicative, Monad, map
from fp.callables import UnaryContract, BinaryContract, ThunkContract, call_once, as_unary
from std.builtin.rebind import downcast, rebind_var
from std.testing import assert_equal

trait BoxType:
    comptime Item:Movable & Deinitable
@fieldwise_init
struct Box[T:Movable & Deinitable](BoxType,Copyable where conforms_to(T,Copyable)):
    comptime Item=Self.T
    var value:Self.T
    def unwrap(deinit self)->Self.T:
        return self.value^

comptime _Item[V:Movable & Deinitable] = downcast[V,BoxType].Item
# One exact error type or Never, as the library requires of combined callbacks.
comptime _Either[A:Movable & Deinitable,B:Movable & Deinitable]:Movable & Deinitable = B if A == Never else A

def _reraise[E:Movable & Deinitable,A:Movable & Deinitable](var error:A) raises E -> Never:
    comptime if A == Never:
        abort("box: unreachable callback error")
    else:
        comptime assert A == E, "box: callbacks must share one error type"
        raise rebind_var[E](error^)

struct BoxFunctor(Functor):
    comptime Element[V:Movable & Deinitable] = _Item[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = Box[F.Out]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        comptime assert V == Box[F.Arg], "box: Box carrier required"
        return Box(call_once(f^,rebind_var[Box[F.Arg]](value^).unwrap()))

struct BoxApplicative(Applicative):
    comptime Element[V:Movable & Deinitable] = _Item[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = BoxFunctor.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = BoxFunctor.MapError[V,F]
    comptime Pure[A:Movable & Deinitable] = Box[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = Box[F.Out]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = _Either[F.Error,R.Error]
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return BoxFunctor.map(f^,value^)
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A) -> Self.Pure[A]:
        return Box(value^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](
        var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]:
        comptime assert V == Box[F.First] and R.Out == Box[F.Second], "box: Box operands required"
        comptime E = Self.CombineError[V,F,R]
        var second:F.Second
        try:
            second = rebind_var[Box[F.Second]](call_once(right^)).unwrap()
        except error:
            _reraise[E](error^)
        try:
            return Box(call_once(f^,rebind_var[Box[F.First]](left^).unwrap(),second^))
        except error:
            _reraise[E](error^)

struct BoxMonad(Monad):
    comptime Element[V:Movable & Deinitable] = _Item[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = BoxFunctor.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = BoxFunctor.MapError[V,F]
    comptime Pure[A:Movable & Deinitable] = BoxApplicative.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = BoxApplicative.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable] = BoxApplicative.CombineError[V,F,R]
    comptime Bound[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return BoxFunctor.map(f^,value^)
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A) -> Self.Pure[A]:
        return BoxApplicative.pure(value^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](
        var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]:
        return BoxApplicative.map2_lazy(f^,left^,right^)
    @staticmethod
    def flat_map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.BindError[V,F] -> Self.Bound[V,F]:
        comptime assert V == Box[F.Arg] and F.Out == Box[_Item[F.Out]], "box: Box callback required"
        return call_once(f^,rebind_var[Box[F.Arg]](value^).unwrap())

from std.os import abort
from fp.algebra import traverse, ListFamily
from . import Add, Next

def box_next(var x:Int)->Box[Int]:
    return Box(x+1)

def twice(var x:Int)->Int:
    return x*2

def generic_map[I:Functor,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var value:V) raises I.MapError[V,F] -> I.Mapped[V,F]:
    return map[I](function^,value^)

