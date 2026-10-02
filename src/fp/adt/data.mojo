"""Algebraic data types and their immutable, shared recursive values."""
from std.memory import ArcPointer
from std.utils import Variant
from std.builtin.rebind import rebind_var, downcast

comptime Value = Movable & Deinitable
"""The bound for constructor fields and results: values that can be moved and destroyed."""


trait CaseList:
    """The constructors of a data type in declaration order; implemented by `Cases`."""

    comptime Subject: Value
    """The stored value: one constructor at a time."""
    comptime count: Int
    """The number of constructors."""
    comptime Case[i: Int]: Value
    """The constructor at position `i`."""

    @staticmethod
    def is_case[i: Int](subject: Self.Subject) -> Bool:
        """Whether `subject` holds constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value.

        Returns:
            True when `subject` holds constructor `i`.
        """
        ...

    @staticmethod
    def get[i: Int](ref subject: Self.Subject) -> ref[subject] Self.Case[i]:
        """The constructor `subject` holds; it must be constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value.

        Returns:
            A reference to the stored constructor.
        """
        ...

    @staticmethod
    def make[i: Int](var value: Self.Case[i]) -> Self.Subject:
        """Store constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            value: The constructor, moved in.

        Returns:
            The stored value.
        """
        ...

    @staticmethod
    def take[i: Int](var subject: Self.Subject) -> Self.Case[i]:
        """Move out the constructor `subject` holds; it must be constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value, consumed.

        Returns:
            The constructor, moved out.
        """
        ...


struct Cases[*Ts: Value](CaseList):
    """The constructors of a data type, in declaration order.

    Parameters:
        Ts: The constructor structs; recursive fields use the layer's `R`.
    """

    comptime Subject = Variant[*Self.Ts]
    comptime count = Variant[*Self.Ts].Ts.length
    comptime Case[i: Int]: Value = Self.Ts[i]

    @staticmethod
    @always_inline
    def is_case[i: Int](subject: Self.Subject) -> Bool:
        """Whether `subject` holds constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value.

        Returns:
            True when `subject` holds constructor `i`.
        """
        return subject.isa[Self.Case[i]]()

    @staticmethod
    @always_inline
    def get[i: Int](ref subject: Self.Subject) -> ref[subject] Self.Case[i]:
        """The constructor `subject` holds; it must be constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value.

        Returns:
            A reference to the stored constructor.
        """
        return subject.unsafe_get[Self.Case[i]]()

    @staticmethod
    @always_inline
    def make[i: Int](var value: Self.Case[i]) -> Self.Subject:
        """Store constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            value: The constructor, moved in.

        Returns:
            The stored value.
        """
        return Self.Subject(value^)

    @staticmethod
    @always_inline
    def take[i: Int](var subject: Self.Subject) -> Self.Case[i]:
        """Move out the constructor `subject` holds; it must be constructor `i`.

        Parameters:
            i: The constructor's position.

        Args:
            subject: The stored value, consumed.

        Returns:
            The constructor, moved out.
        """
        return subject^.unwrap[Self.Case[i]]()


trait Data:
    """An algebraic data type: its constructors, with recursive positions typed by `R`.

    A recursive position is a field of type `R`, `List[R]` or `Optional[R]`. A
    constructor may take several type parameters, so that a clause can treat its
    fields differently; the layer passes `R` to each.
    """

    comptime Layer[R: Value]: CaseList
    """The constructors with every recursive position filled by `R`."""


# ----------------------------------------------------------------- shapes

comptime _FIELD = 0
comptime _ONE = 1
comptime _MANY = 2
comptime _MAYBE = 3


def _shape[F: Data, T: AnyType]() -> Int:
    """How a stored field of type `T` holds children."""
    comptime if T == Node[F]:
        return _ONE
    elif T == List[Node[F]]:
        return _MANY
    elif T == Optional[Node[F]]:
        return _MAYBE
    return _FIELD


struct _Probe(Movable):
    """A stand-in for `R` that no user field can mention."""
    pass


def _index[S: CaseList, C: AnyType]() -> Int:
    comptime for i in range(S.count):
        comptime if S.Case[i] == C:
            return i
    return -1


def _admit_data[F: Data]() -> Bool:
    """A declaration's rules: distinct constructor names; `R` only in recursive positions."""
    comptime Stored = F.Layer[Node[F]]
    comptime Probe = F.Layer[_Probe]
    comptime assert Stored.count == Probe.count, "Data: the layer must list the same constructors for every R"
    comptime for i in range(Stored.count):
        comptime C = Stored.Case[i]
        comptime assert reflect[C].is_struct(), "Data: constructor " + reflect[C].name() + " must be a struct"
        comptime for k in range(i):
            comptime assert reflect[Stored.Case[k]].base_name() != reflect[C].base_name(), (
                "Data: two constructors are named " + reflect[C].base_name())
        comptime In = reflect[C].field_types()
        comptime Out = reflect[Probe.Case[i]].field_types()
        comptime for f in range(reflect[C].field_count()):
            comptime if In[f] != Out[f]:
                comptime assert _shape[F, In[f]]() != _FIELD, (
                    "Data: field " + String(reflect[C].field_names()[f]) + " of " + reflect[C].base_name()
                    + " uses R; a recursive field has type R, List[R] or Optional[R]")
    return True


def _height[F: Data, C: AnyType](value: C) -> Int:
    var height = 0
    comptime Fs = reflect[C].field_types()
    comptime for f in range(reflect[C].field_count()):
        comptime shape = _shape[F, Fs[f]]()
        comptime if shape == _ONE:
            height = max(height, rebind[Node[F]](reflect[C].field_ref[f](value))._cell[].height)
        elif shape == _MANY:
            for item in rebind[List[Node[F]]](reflect[C].field_ref[f](value)):
                height = max(height, item._cell[].height)
        elif shape == _MAYBE:
            ref item = rebind[Optional[Node[F]]](reflect[C].field_ref[f](value))
            if item:
                height = max(height, item.value()._cell[].height)
    return height + 1


def _collect[F: Data, C: AnyType](value: C, mut into: List[Node[F]]):
    """Append the children of `value`, sharing them."""
    comptime Fs = reflect[C].field_types()
    comptime for f in range(reflect[C].field_count()):
        comptime shape = _shape[F, Fs[f]]()
        comptime if shape == _ONE:
            into.append(rebind[Node[F]](reflect[C].field_ref[f](value)))
        elif shape == _MANY:
            for item in rebind[List[Node[F]]](reflect[C].field_ref[f](value)):
                into.append(item)
        elif shape == _MAYBE:
            ref item = rebind[Optional[Node[F]]](reflect[C].field_ref[f](value))
            if item:
                into.append(item.value())


struct _Cell[F: Data](Movable):
    var layer: Self.F.Layer[Node[Self.F]].Subject
    var height: Int

    def __init__(out self, var layer: Self.F.Layer[Node[Self.F]].Subject, height: Int):
        self.layer = layer^
        self.height = height


trait _NodeType:
    """Implemented by `Node` alone, so generic code can recognize a value of a data type."""

    comptime Of: Data


struct Node[F: Data](ImplicitlyCopyable, Movable, _NodeType):
    """An immutable value of data type `F`: one constructor whose recursive fields hold Nodes.

    A Node can only refer to Nodes that already exist and cannot change after
    construction, so a Node and everything it reaches form a finite acyclic
    graph. Copying a Node shares it in constant time. Each Node stores its
    height, the longest path to a leaf, and is released in a loop, so values of
    any depth can be built and dropped.

    Parameters:
        F: The data type.
    """

    comptime Layer = Self.F.Layer[Node[Self.F]]
    """The stored constructors, with recursive fields holding Nodes."""
    comptime Of: Data = Self.F
    """The data type."""
    var _cell: ArcPointer[_Cell[Self.F]]

    @implicit
    def __init__[C: Value](out self, var value: C):
        """Store one constructor; its recursive fields hold existing Nodes.

        Parameters:
            C: The constructor, with recursive fields of type `Node[F]`.

        Args:
            value: The constructor value, moved in.
        """
        comptime assert _admit_data[Self.F]()
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, (
            "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
            + " with Node children")
        var height = _height[Self.F](value)
        self._cell = ArcPointer(_Cell[Self.F](Self.Layer.make[i](rebind_var[Self.Layer.Case[i]](value^)), height))

    def __init__(out self, *, copy: Self):
        """Share `copy`."""
        self._cell = copy._cell

    def __deinit__(deinit self):
        """Release the value; children it alone owned are released in a loop, not recursively."""
        if self._cell.count() != 1:
            return
        var pending = List[Node[Self.F]]()
        _collect_children[Self.F](self._cell[].layer, pending)
        _ = self._cell^
        while pending:
            var node = pending.pop()
            if node._cell.count() == 1:
                _collect_children[Self.F](node._cell[].layer, pending)
            # `node` is released here; its children are still held by `pending`,
            # so its own release only shares them and does not descend.

    def isa[C: AnyType](self) -> Bool:
        """Whether the value is constructor `C` (with Node children).

        Parameters:
            C: A constructor of `F`.

        Returns:
            True when the value holds `C`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node.isa: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return Self.Layer.is_case[i](self._cell[].layer)

    def __getitem_param__[C: AnyType](self) -> ref[self._cell[].layer] C:
        """The constructor the value holds, which must be `C`.

        Parameters:
            C: A constructor of `F`, with Node children.

        Returns:
            A reference to the stored constructor.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        debug_assert[assert_mode="safe"](Self.Layer.is_case[i](self._cell[].layer), "Node: wrong constructor")
        return rebind[C](Self.Layer.get[i](self._cell[].layer))

    def __eq__[C: Equatable & Value](self, other: C) -> Bool:
        """Whether the value is constructor `C` and equal to `other`.

        Parameters:
            C: An `Equatable` constructor of `F`.

        Args:
            other: The constructor value to compare with.

        Returns:
            True when the constructor matches and its value equals `other`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        ref layer = self._cell[].layer
        return Self.Layer.is_case[i](layer) and rebind[C](Self.Layer.get[i](layer)) == other

    def __is__(self, other: Self) -> Bool:
        """Whether both are the same shared value."""
        return self._cell is other._cell


def _collect_children[F: Data](layer: F.Layer[Node[F]].Subject, mut into: List[Node[F]]):
    comptime S = F.Layer[Node[F]]
    comptime for i in range(S.count):
        if S.is_case[i](layer):
            _collect[F](S.get[i](layer), into)
            return


# ----------------------------------------------------------------- inline values

def _recursive_field[F: Data]() -> String:
    """The first recursive field of `F`'s constructors, for a diagnostic; empty when there is none."""
    comptime Stored = F.Layer[Node[F]]
    comptime Probe = F.Layer[_Probe]
    comptime for i in range(Stored.count):
        comptime C = Stored.Case[i]
        comptime In = reflect[C].field_types()
        comptime Out = reflect[Probe.Case[i]].field_types()
        comptime for f in range(reflect[C].field_count()):
            comptime if In[f] != Out[f]:
                return String(reflect[C].field_names()[f]) + " of " + reflect[C].base_name()
    return ""


def _admit_choice[F: Data]() -> Bool:
    """A declaration's rules, and no recursive field: a value stored in place holds no children."""
    comptime assert _admit_data[F]()
    comptime field = _recursive_field[F]()
    comptime assert field == "", (
        "Choice: field " + field + " is recursive; a value of a recursive data type is a Node")
    return True


trait _ChoiceType:
    """A value that holds one constructor of a non-recursive data type in place.

    The value stores the constructor in its one field of type
    `Of.Layer[Node[Of]].Subject`, a native `Variant`; `_layer` reaches it.
    """

    comptime Of: Data


def _layer_field[S: AnyType, L: AnyType]() -> Int:
    comptime for f in range(reflect[S].field_count()):
        comptime if reflect[S].field_types()[f] == L:
            return f
    return -1


def _layer[F: Data, S: AnyType](ref subject: S) -> ref[subject] F.Layer[Node[F]].Subject:
    """The stored constructor of an inline value of data type `F`."""
    comptime L = F.Layer[Node[F]].Subject
    comptime f = _layer_field[S, L]()
    comptime assert f >= 0, reflect[S].name() + " stores no " + reflect[L].name()
    return rebind[L](reflect[S].field_ref[f](subject))


struct Choice[F: Data](
    _ChoiceType, Movable,
    Copyable where conforms_to(F.Layer[Node[F]].Subject, Copyable),
    ImplicitlyCopyable where conforms_to(F.Layer[Node[F]].Subject, ImplicitlyCopyable),
):
    """A value of a non-recursive data type `F`, stored in place: one of its constructors.

    Unlike a `Node`, a Choice is owned, not shared: copying it copies the
    constructor, and moving it moves it. It needs no allocation, and its
    constructors need not be copyable; it is `Copyable`, or `ImplicitlyCopyable`,
    when all of them are. A constructor converts to a Choice implicitly.

    Parameters:
        F: The data type; none of its fields is recursive.
    """

    comptime Layer = Self.F.Layer[Node[Self.F]]
    """The constructors."""
    comptime Of: Data = Self.F
    """The data type."""
    var _value: Self.Layer.Subject

    @implicit
    def __init__[C: Value](out self, var value: C):
        """Store one constructor.

        Parameters:
            C: A constructor of `F`.

        Args:
            value: The constructor value, moved in.
        """
        comptime assert _admit_choice[Self.F]()
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Choice: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        self._value = Self.Layer.make[i](rebind_var[Self.Layer.Case[i]](value^))

    def isa[C: AnyType](self) -> Bool:
        """Whether the value is constructor `C`.

        Parameters:
            C: A constructor of `F`.

        Returns:
            True when the value holds `C`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Choice.isa: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return Self.Layer.is_case[i](self._value)

    def __getitem_param__[C: AnyType](ref self) -> ref[self._value] C:
        """The constructor the value holds, which must be `C`.

        Parameters:
            C: A constructor of `F`.

        Returns:
            A reference to the stored constructor.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Choice: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        debug_assert[assert_mode="safe"](Self.Layer.is_case[i](self._value), "Choice: wrong constructor")
        return rebind[C](Self.Layer.get[i](self._value))

    def unwrap[C: Value](deinit self) -> C:
        """Consume the value and return its constructor, which must be `C`.

        Parameters:
            C: A constructor of `F`.

        Returns:
            The stored constructor, moved out.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Choice: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return rebind_var[C](Self.Layer.take[i](self._value^))

    def __eq__[C: Equatable & Value](self, other: C) -> Bool:
        """Whether the value is constructor `C` and equal to `other`.

        Parameters:
            C: An `Equatable` constructor of `F`.

        Args:
            other: The constructor value to compare with.

        Returns:
            True when the constructor matches and its value equals `other`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Choice: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return Self.Layer.is_case[i](self._value) and rebind[C](Self.Layer.get[i](self._value)) == other
