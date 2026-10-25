"""N-ary combination derived once from Applicative map and map2_lazy."""
from std.builtin.variadics import TypeList
from std.builtin.rebind import rebind_var, rebind
from fp.algebra.protocols import Applicative
from fp.callables.protocols import Unary, UnaryContract, Binary
from fp.callables._transforms import _ValueThunk
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from fp.algebra._admission import _CarrierCompatible

from fp.callables.products import _OptionalCell
@fieldwise_init
struct _Singleton[A: Movable & Deinitable](Unary, Copyable, Defaultable):
    comptime Arg = Self.A
    comptime Out = Tuple[Self.A]
    def call(self, var arg: Self.Arg) -> Self.Out: return (arg^,)
@fieldwise_init
struct _AppendTuple[B: Movable & Deinitable, *As: Movable & Deinitable](Binary, Copyable, Defaultable):
    comptime First = Tuple[*Self.As]
    comptime Second = Self.B
    comptime Out = Tuple[*TypeList._concat[Self.As.values, TypeList.of[Trait=Movable & Deinitable, Self.B]().values]()]
    def call(self, var first: Self.First, var second: Self.Second) -> Self.Out:
        var joined = first^.concat((second^,))
        comptime assert type_of(joined) == Self.Out
        return rebind_var[Self.Out](joined^)
struct _ProductRun[I: Applicative, V: Movable & Deinitable, *Ws: Movable & Deinitable]:
    """Consume operands once and left-associate the family combination.

    Optional slots own unvisited operands if construction raises. Each right
    value enters map2_lazy through the canonical already-computed thunk. The
    exact output and error are supplied by admission, then checked here; this
    keeps variadic execution independent of native return-type inference.
    """
    comptime Element[index: Int]: Movable & Deinitable = Self.I.Element[Self.V] if index == 0 else Self.I.Element[Self.Ws[index-1]]
    comptime Of[From: Movable & Deinitable]: Movable & Deinitable = Self.I.Element[From]
    comptime Elements = TypeList._concat[TypeList.of[Trait=Movable & Deinitable, Self.I.Element[Self.V]]().values, Self.Ws.map[Self.Of[_]]().values]()
    comptime Prefix[index: Int] = Self.Elements.slice[0,index]()
    comptime Step[index: Int] = _AppendTuple[Self.Element[index], *Self.Prefix[index]]
    comptime Native[W: Movable & Deinitable]: Bool = W == Self.I.Pure[Self.I.Element[W]]
    comptime NativeInputs = Self.Native[Self.V] and Self.Ws.all[Self.Native[_]]()
    comptime Admitted[W: Movable & Deinitable] = _CarrierCompatible[Self.I, W]
    comptime AdmittedInputs = Self.Admitted[Self.V] and Self.Ws.all[Self.Admitted[_]]()
    comptime Payload = Tuple[*Self.Elements]
    comptime Slots = Self.Ws.map[_OptionalCell]()
    @staticmethod
    def step[index: Int, Out: Movable & Deinitable, X: Movable & Deinitable, Current: Movable & Deinitable](var value: Current, mut cells: Tuple[*Self.Slots]) raises X -> Out:
        comptime if index == Self.Ws.length:
            comptime assert Current == Out
            return rebind_var[Out](value^)
        else:
            comptime assert Self.Slots[index] == Optional[Self.Ws[index]]
            var next_value = rebind[Optional[Self.Ws[index]]](cells[index]).unsafe_take()
            var joined: Self.I.Combined[Current,Self.Step[index+1],_ValueThunk[Self.Ws[index]]]
            try:
                joined = Self.I.map2_lazy(Self.Step[index+1](), value^, _ValueThunk(next_value^))
            except error:
                comptime assert _ErrorCompatible[X,type_of(error)]
                _propagate_error[X](error^)
            return Self.step[index+1,Out,X](joined^,cells)
    @staticmethod
    def run[Out: Movable & Deinitable, X: Movable & Deinitable](var first: Self.V, var others: Tuple[*Self.Ws]) raises X -> Out:
        comptime assert Self.Slots.all_conforms_to[Defaultable]()
        var cells = Tuple[*Self.Slots]()
        def store[index: Int](var value: Self.Ws[index]) {ref cells}:
            comptime assert Self.Slots[index] == Optional[Self.Ws[index]]
            rebind[Optional[Self.Ws[index]]](cells[index]) = Optional(value^)
        others^.consume_elements(store)
        var start: Self.I.Mapped[Self.V, _Singleton[Self.I.Element[Self.V]]]
        try:
            start = Self.I.map(_Singleton[Self.I.Element[Self.V]](),first^)
        except error:
            comptime assert _ErrorCompatible[X,type_of(error)]
            _propagate_error[X](error^)
        return Self.step[0,Out,X](start^,cells)


def _map_n_as[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //,
              I: Applicative, Product: Movable & Deinitable, Out: Movable & Deinitable,
              X: Movable & Deinitable, *Ws: Movable & Deinitable](
    var function: F, var first: V, var others: Tuple[*Ws]
) raises X -> Out:
    comptime assert F.Arg == _ProductRun[I,V,*Ws].Payload, "map_n: exact tuple payload required"
    var combined = _ProductRun[I,V,*Ws].run[Product,X](first^,others^)
    comptime assert I.Mapped[Product,F] == Out
    try:
        return rebind_var[Out](I.map(function^,combined^))
    except error:
        comptime assert _ErrorCompatible[X,type_of(error)]
        _propagate_error[X](error^)


# --- n-ary type inference (generated) ---
# Generated by scripts/generate_nary_syntax.py; only native type descriptions live here.

struct _ProductTypes[I: Applicative, V: Movable & Deinitable, *Ws: Movable & Deinitable]:
    # Mojo 1.1 rejects recursive associated aliases. Name the finite native
    # boundaries here; _ProductRun owns all sequencing, cleanup and errors.
    comptime Run = _ProductRun[Self.I, Self.V, *Self.Ws]
    comptime S0 = Self.I.Mapped[Self.V, _Singleton[Self.I.Element[Self.V]]]
    comptime E0 = Self.I.MapError[Self.V, _Singleton[Self.I.Element[Self.V]]]
    comptime S1: Movable & Deinitable = Self.I.Combined[Self.S0, _AppendTuple[Self.I.Element[Self.Ws[0]], Self.I.Element[Self.V]], _ValueThunk[Self.Ws[0]]] if Self.Ws.length >= 1 else Self.S0
    comptime E1: Movable & Deinitable = _CommonError[Self.E0, Self.I.CombineError[Self.S0, _AppendTuple[Self.I.Element[Self.Ws[0]], Self.I.Element[Self.V]], _ValueThunk[Self.Ws[0]]]] if Self.Ws.length >= 1 else Self.E0
    comptime S2: Movable & Deinitable = Self.I.Combined[Self.S1, _AppendTuple[Self.I.Element[Self.Ws[1]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]]], _ValueThunk[Self.Ws[1]]] if Self.Ws.length >= 2 else Self.S1
    comptime E2: Movable & Deinitable = _CommonError[Self.E1, Self.I.CombineError[Self.S1, _AppendTuple[Self.I.Element[Self.Ws[1]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]]], _ValueThunk[Self.Ws[1]]]] if Self.Ws.length >= 2 else Self.E1
    comptime S3: Movable & Deinitable = Self.I.Combined[Self.S2, _AppendTuple[Self.I.Element[Self.Ws[2]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]]], _ValueThunk[Self.Ws[2]]] if Self.Ws.length >= 3 else Self.S2
    comptime E3: Movable & Deinitable = _CommonError[Self.E2, Self.I.CombineError[Self.S2, _AppendTuple[Self.I.Element[Self.Ws[2]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]]], _ValueThunk[Self.Ws[2]]]] if Self.Ws.length >= 3 else Self.E2
    comptime S4: Movable & Deinitable = Self.I.Combined[Self.S3, _AppendTuple[Self.I.Element[Self.Ws[3]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]]], _ValueThunk[Self.Ws[3]]] if Self.Ws.length >= 4 else Self.S3
    comptime E4: Movable & Deinitable = _CommonError[Self.E3, Self.I.CombineError[Self.S3, _AppendTuple[Self.I.Element[Self.Ws[3]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]]], _ValueThunk[Self.Ws[3]]]] if Self.Ws.length >= 4 else Self.E3
    comptime S5: Movable & Deinitable = Self.I.Combined[Self.S4, _AppendTuple[Self.I.Element[Self.Ws[4]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]]], _ValueThunk[Self.Ws[4]]] if Self.Ws.length >= 5 else Self.S4
    comptime E5: Movable & Deinitable = _CommonError[Self.E4, Self.I.CombineError[Self.S4, _AppendTuple[Self.I.Element[Self.Ws[4]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]]], _ValueThunk[Self.Ws[4]]]] if Self.Ws.length >= 5 else Self.E4
    comptime S6: Movable & Deinitable = Self.I.Combined[Self.S5, _AppendTuple[Self.I.Element[Self.Ws[5]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]], Self.I.Element[Self.Ws[4]]], _ValueThunk[Self.Ws[5]]] if Self.Ws.length >= 6 else Self.S5
    comptime E6: Movable & Deinitable = _CommonError[Self.E5, Self.I.CombineError[Self.S5, _AppendTuple[Self.I.Element[Self.Ws[5]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]], Self.I.Element[Self.Ws[4]]], _ValueThunk[Self.Ws[5]]]] if Self.Ws.length >= 6 else Self.E5
    comptime S7: Movable & Deinitable = Self.I.Combined[Self.S6, _AppendTuple[Self.I.Element[Self.Ws[6]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]], Self.I.Element[Self.Ws[4]], Self.I.Element[Self.Ws[5]]], _ValueThunk[Self.Ws[6]]] if Self.Ws.length >= 7 else Self.S6
    comptime E7: Movable & Deinitable = _CommonError[Self.E6, Self.I.CombineError[Self.S6, _AppendTuple[Self.I.Element[Self.Ws[6]], Self.I.Element[Self.V], Self.I.Element[Self.Ws[0]], Self.I.Element[Self.Ws[1]], Self.I.Element[Self.Ws[2]], Self.I.Element[Self.Ws[3]], Self.I.Element[Self.Ws[4]], Self.I.Element[Self.Ws[5]]], _ValueThunk[Self.Ws[6]]]] if Self.Ws.length >= 7 else Self.E6
    comptime Out = Self.S7
    comptime Error = Self.E7

struct _MapNTypes[I: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, *Ws: Movable & Deinitable]:
    comptime Product = _ProductTypes[Self.I, Self.V, *Self.Ws]
    comptime Out = Self.I.Mapped[Self.Product.Out, Self.F]
    comptime Error = _CommonError[Self.Product.Error, Self.I.MapError[Self.Product.Out, Self.F]]

# --- end n-ary type inference ---
