"""Fixed-arity callable protocols and borrowed endpoints: the types every callback is called through."""


# Fixed-arity library callables. A contract holds the types and each receiver
# mode is its own trait: an implementation provides only the modes it supports.
# Algorithms call through `call_once` and `call_repeated`, which admit any mode
# for a single call and a shared or mutable receiver for repeated calls.
trait CallContract:
    """The common result and error of owned-argument callables and thunks.

    `UnaryContract`, `BinaryContract` and `ThunkContract` inherit it. Types
    implementing several arities share one `Out` and `Error`; each arity
    declares only its inputs. Conditional implementations of multiple arities
    declare this common ancestor explicitly.
    """
    comptime Out: Movable & Deinitable
    """The result type."""
    comptime Error: Movable & Deinitable = Never
    """The error type; `Never` for a callable that does not raise."""


trait UnaryContract(CallContract):
    """The types of a callable that takes one owned argument.

    A library callable fixes its argument, result and error types here, and
    implements the receiver modes it supports: `Unary`, `MutableUnary` or
    `OnceUnary`.
    """
    comptime Arg: Movable & Deinitable
    """The argument type."""


trait Unary(UnaryContract, Movable, Deinitable):
    """A one-argument callable that can be called repeatedly through a shared receiver.

    `Partial`, `Composition`, `Flipped`, `Identity` and `NativeUnary` implement
    it. Algorithms call it through `call_once` or `call_repeated`.
    """
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call with one owned argument.

        The receiver is borrowed, so the value can be called again.

        Args:
            arg: The argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait MutableUnary(UnaryContract, Movable, Deinitable):
    """A one-argument callable that can be called repeatedly with exclusive access to its state."""
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call with one owned argument.

        The receiver is borrowed mutably, so the call may update its state,
        and the value can be called again.

        Args:
            arg: The argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait OnceUnary(UnaryContract, Movable, Deinitable):
    """A one-argument callable that is called at most once, consuming its state."""
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call with one owned argument.

        The call consumes the receiver.

        Args:
            arg: The argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait BinaryContract(CallContract):
    """The types of a callable that takes two owned arguments.

    A library callable implements the receiver modes it supports: `Binary`,
    `MutableBinary` or `OnceBinary`.
    """
    comptime First: Movable & Deinitable
    """The first argument's type."""
    comptime Second: Movable & Deinitable
    """The second argument's type."""


trait Binary(BinaryContract, Movable, Deinitable):
    """A two-argument callable that can be called repeatedly through a shared receiver."""
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call with two owned arguments.

        The receiver is borrowed, so the value can be called again.

        Args:
            first: The first argument, consumed.
            second: The second argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait MutableBinary(BinaryContract, Movable, Deinitable):
    """A two-argument callable that can be called repeatedly with exclusive access to its state."""
    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call with two owned arguments.

        The receiver is borrowed mutably, so the call may update its state,
        and the value can be called again.

        Args:
            first: The first argument, consumed.
            second: The second argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait OnceBinary(BinaryContract, Movable, Deinitable):
    """A two-argument callable that is called at most once, consuming its state."""
    def call_once(deinit self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call with two owned arguments.

        The call consumes the receiver.

        Args:
            first: The first argument, consumed.
            second: The second argument, consumed.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait ThunkContract(CallContract):
    """The types of a callable that takes no argument: a deferred producer.

    A library callable implements the receiver modes it supports: `Thunk`,
    `MutableThunk` or `OnceThunk`.
    """
    pass

trait Thunk(ThunkContract, Movable, Deinitable):
    """A producer that can be called repeatedly through a shared receiver."""
    def call(self) raises Self.Error -> Self.Out:
        """Produce a value.

        The receiver is borrowed, so the value can be called again.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait MutableThunk(ThunkContract, Movable, Deinitable):
    """A producer that can be called repeatedly with exclusive access to its state."""
    def call_mut(mut self) raises Self.Error -> Self.Out:
        """Produce a value.

        The receiver is borrowed mutably, so the call may update its state,
        and the value can be called again.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...

trait OnceThunk(ThunkContract, Movable, Deinitable):
    """A producer that is called at most once, consuming its state; `attempt_once` takes one."""
    def call_once(deinit self) raises Self.Error -> Self.Out:
        """Produce a value.

        The call consumes the receiver.

        Returns:
            The result.

        Raises:
            `Error`, the callable's own error type; nothing when it is `Never`.
        """
        ...


trait BorrowCallContract:
    """The types of a callable that borrows its argument.

    The payload is borrowed for the duration of the call, so it need not be
    movable, and the callable cannot keep a reference to it.
    """
    comptime Payload: AnyType
    """The borrowed argument's type."""
    comptime Result: Movable & Deinitable
    """The result type."""
    comptime Failure: Movable & Deinitable = Never
    """The error type; `Never` for a callable that does not raise."""


trait BorrowCallable(BorrowCallContract, Movable, Deinitable):
    """A callable that borrows its argument and can be called repeatedly.

    Iteration predicates, `while_loop` predicates, `Result.fold` and Reader's
    `local` and `action` take one. `invoke_borrowed` calls it.
    """
    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        """Call with a borrowed argument.

        Args:
            payload: The argument, borrowed for the call.

        Returns:
            The result.

        Raises:
            `Failure`, the callable's own error type; nothing when it is `Never`.
        """
        ...


trait BorrowMutableCallable(BorrowCallContract, Movable, Deinitable):
    """A repeatable callable that mutates its receiver while borrowing its argument.

    The payload is never consumed or retained. `invoke_borrowed_repeated`
    selects this receiver before a shared receiver when both are available.
    """
    def invoke_mut(mut self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        """Call with exclusive receiver access and a borrowed payload.

        Args:
            payload: The argument, borrowed only for this call.

        Returns:
            The result, retaining its native type and origins.

        Raises:
            `Failure`, the callable's exact error; `Never` for a pure call.
        """
        ...


trait BorrowOnceCallable(BorrowCallContract, Movable, Deinitable):
    """A callable that borrows its argument and is called at most once, consuming its state.

    `Result.fold_once` and Reader's `action` take one. `invoke_borrowed_once`
    calls it.
    """
    def invoke_once(deinit self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        """Call once with a borrowed argument, consuming the receiver.

        Args:
            payload: The argument, borrowed for the call.

        Returns:
            The result.

        Raises:
            `Failure`, the callable's own error type; nothing when it is `Never`.
        """
        ...


# Native boundaries project family errors through this type-only signature.
# Keeping it independent of callback storage lets generic native declarations
# retain explicit error evidence; operation bodies check the actual callback.
struct _ErrorProbe[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable](UnaryContract):
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E


# The borrowing counterpart, for predicates and other borrowing callbacks.
struct _BorrowErrorProbe[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable](BorrowCallContract):
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Self.E
